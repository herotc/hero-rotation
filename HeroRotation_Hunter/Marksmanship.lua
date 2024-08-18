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
local Hunter = HR.Commons.Hunter
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
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Stronger, VarTrinket2Stronger
local Enemies10ySplash, EnemiesCount10ySplash
local TargetInRange40y
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables (from Precombat) =====
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

  VarTrinket1Spell = Trinket1:OnUseSpell()
  VarTrinket1Range = (VarTrinket1Spell and VarTrinket1Spell.MaximumRange > 0 and VarTrinket1Spell.MaximumRange <= 100) and VarTrinket1Spell.MaximumRange or 100
  VarTrinket2Spell = Trinket2:OnUseSpell()
  VarTrinket2Range = (VarTrinket2Spell and VarTrinket2Spell.MaximumRange > 0 and VarTrinket2Spell.MaximumRange <= 100) and VarTrinket2Spell.MaximumRange or 100

  VarTrinket1CD = Trinket1:Cooldown()
  VarTrinket2CD = Trinket2:Cooldown()

  VarTrinket1BL = Player:IsItemBlacklisted(Trinket1)
  VarTrinket2BL = Player:IsItemBlacklisted(Trinket2)

  -- variable,name=trinket_1_stronger,value=!trinket.2.has_cooldown|trinket.1.has_use_buff&(!trinket.2.has_use_buff|!trinket.1.is.mirror_of_fractured_tomorrows&(trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))|!trinket.1.has_use_buff&(!trinket.2.has_use_buff&(trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))
  VarTrinket1Stronger = VarTrinket1CD == 0 or Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() or not VarTrinket1ID == I.MirrorofFracturedTomorrows:ID() and (VarTrinket2ID == I.MirrorofFracturedTomorrows:ID() or VarTrinket2CD < VarTrinket1CD or VarTrinket2Spell:CastTime() < VarTrinket1Spell:CastTime() or VarTrinket2Spell:CastTime() == VarTrinket1Spell:CastTime() and VarTrinket2CD == VarTrinket1CD)) or not Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() and (VarTrinket2CD < VarTrinket1CD or VarTrinket2Spell:CastTime() < VarTrinket1Spell:CastTime() or VarTrinket2Spell:CastTime() == VarTrinket1Spell:CastTime() and VarTrinket2CD == VarTrinket1CD))
  VarTrinket2Stronger = not VarTrinket1Stronger
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  { S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end },
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  Hunter.SteadyFocus.Count = 0
  Hunter.SteadyFocus.LastCast = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.SerpentSting:RegisterInFlight()
  S.SteadyShot:RegisterInFlight()
  S.AimedShot:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.SerpentSting:RegisterInFlight()
S.SteadyShot:RegisterInFlight()
S.AimedShot:RegisterInFlight()

--- ===== Helper Functions =====
local function TrickShotsBuffCheck()
  return (Player:BuffUp(S.TrickShotsBuff) and not Player:IsCasting(S.AimedShot) and not Player:IsChanneling(S.RapidFire)) or Player:BuffUp(S.VolleyBuff)
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterAimedShot(TargetUnit)
  -- target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99
  return (TargetUnit:DebuffRemains(S.SerpentStingDebuff) + num(S.SerpentSting:InFlight()) * 99)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- summon_pet,if=!talent.lone_wolf
  -- Note: Moved pet management to APL()
  -- snapshot_stats
  -- variable,name=trinket_1_stronger,value=!trinket.2.has_cooldown|trinket.1.has_use_buff&(!trinket.2.has_use_buff|!trinket.1.is.mirror_of_fractured_tomorrows&(trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))|!trinket.1.has_use_buff&(!trinket.2.has_use_buff&(trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))
  -- variable,name=trinket_2_stronger,value=!variable.trinket_1_stronger
  -- Note: Moved to variable declarations and PLAYER_EQUIPMENT_CHANGED registration.
  -- salvo,precast_time=10
  if S.Salvo:IsCastable() then
    if Cast(S.Salvo, Settings.Marksmanship.OffGCDasOffGCD.Salvo) then return "salvo precombat 2"; end
  end
  -- aimed_shot,if=active_enemies<3&(!talent.volley|active_enemies<2)
  -- Note: We can't actually get target counts before combat begins.
  if S.AimedShot:IsReady() and not Player:IsCasting(S.AimedShot) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot precombat 6"; end
  end
  -- steady_shot,if=active_enemies>2|talent.volley&active_enemies=2
  -- Note: We can't get target counts before combat begins.
end

local function CDs()
  -- invoke_external_buff,name=power_infusion,if=buff.trueshot.remains>12
  -- Note: Not handling external buffs.
  -- berserking,if=buff.trueshot.up|fight_remains<13
  if S.Berserking:IsReady() and (Player:BuffUp(S.TrueshotBuff) or FightRemains < 13) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 2"; end
  end
  -- blood_fury,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<16
  if S.BloodFury:IsReady() and (Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30 or FightRemains < 16) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 4"; end
  end
  -- ancestral_call,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<16
  if S.AncestralCall:IsReady() and (Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30 or FightRemains < 16) then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 6"; end
  end
  -- fireblood,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<9
  if S.Fireblood:IsReady() and (Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30 or FightRemains < 9) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 8"; end
  end
  -- lights_judgment,if=buff.trueshot.down
  if S.LightsJudgment:IsReady() and (Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cds 10"; end
  end
  -- potion,if=buff.trueshot.up&(buff.bloodlust.up|target.health.pct<20)|fight_remains<26
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.TrueshotBuff) and (Player:BloodlustUp() or Target:HealthPercentage() < 20) or FightRemains < 26) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 12"; end
    end
  end
  -- salvo,if=active_enemies>2|cooldown.volley.remains<10
  if S.Salvo:IsCastable() and (EnemiesCount10ySplash > 2 or S.Volley:CooldownRemains() < 10) then
    if Cast(S.Salvo, Settings.Marksmanship.OffGCDasOffGCD.Salvo) then return "salvo cds 14"; end
  end
end

local function ST()
  -- steady_shot,if=talent.steady_focus&steady_focus_count&buff.steady_focus.remains<8
  if S.SteadyShot:IsCastable() and (S.SteadyFocus:IsAvailable() and Hunter.SteadyFocus.Count == 1 and Player:BuffRemains(S.SteadyFocusBuff) < 8) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 2"; end
  end
  -- kill_shot,if=buff.razor_fragments.up
  if S.KillShot:IsReady() and (Player:BuffUp(S.RazorFragmentsBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot st 4"; end
  end
  -- black_arrow
  if S.BlackArrow:IsReady() then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow st 6"; end
  end
  -- explosive_shot,if=active_enemies>1
  if S.ExplosiveShot:IsReady() and (EnemiesCount10ySplash > 1) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot st 8"; end
  end
  -- volley
  if S.Volley:IsReady() then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley st 10"; end
  end
  -- rapid_fire,if=!talent.lunar_storm|(!cooldown.lunar_storm.remains|cooldown.lunar_storm.remains>5)
  if S.RapidFire:IsCastable() and (not S.LunarStorm:IsAvailable() or (S.LunarStorm:CooldownDown() or S.LunarStorm:CooldownRemains() > 5)) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire st 12"; end
  end
  -- trueshot,if=variable.trueshot_ready
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot st 14"; end
  end
  -- multishot,if=buff.salvo.up&!talent.volley
  if S.MultiShot:IsReady() and (Player:BuffUp(S.SalvoBuff) and not S.Volley:IsAvailable()) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot st 16"; end
  end
  -- wailing_arrow
  if S.WailingArrow:IsReady() then
    if Cast(S.WailingArrow, Settings.Marksmanship.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow st 18"; end
  end
  -- aimed_shot,target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99,if=buff.precise_shots.down|(buff.trueshot.up|full_recharge_time<gcd+cast_time)&(active_enemies<2|!talent.chimaera_shot)|(buff.trick_shots.remains>execute_time&active_enemies>1)
  if S.AimedShot:IsReady() and (Player:BuffDown(S.PreciseShotsBuff) or (Player:BuffUp(S.TrueshotBuff) or S.AimedShot:FullRechargeTime() < Player:GCD() + S.AimedShot:CastTime()) and (EnemiesCount10ySplash < 2 or not S.ChimaeraShot:IsAvailable()) or (Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:ExecuteTime() and EnemiesCount10ySplash > 1)) then
    if Everyone.CastTargetIf(S.AimedShot, Enemies10ySplash, "min", EvaluateTargetIfFilterAimedShot, nil, not TargetInRange40y) then return "aimed_shot st 20"; end
  end
  -- steady_shot,if=talent.steady_focus&buff.steady_focus.down&buff.trueshot.down
  if S.SteadyShot:IsCastable() and (S.SteadyFocus:IsAvailable() and Player:BuffDown(S.SteadyFocusBuff) and Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 22"; end
  end
  -- chimaera_shot,if=buff.precise_shots.up
  if S.ChimaeraShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff)) then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "chimaera_shot st 24"; end
  end
  -- arcane_shot,if=buff.precise_shots.up
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff)) then
    if Cast(S.ArcaneShot, nil, nil, not TargetInRange40y) then return "arcane_shot st 26"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot st 28"; end
  end
  -- barrage,if=talent.rapid_fire_barrage
  if S.Barrage:IsReady() and (S.RapidFireBarrage:IsAvailable()) then
    if Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "barrage st 30"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot st 32"; end
  end
  -- arcane_shot,if=focus>cost+action.aimed_shot.cost
  if S.ArcaneShot:IsReady() and (Player:FocusP() > S.ArcaneShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.ArcaneShot, nil, nil, not TargetInRange40y) then return "arcane_shot st 34"; end
  end
  -- bag_of_tricks,if=buff.trueshot.down
  if CDsON() and S.BagofTricks:IsReady() then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks st 36"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 39"; end
  end
end

local function Trickshots()
  -- steady_shot,if=talent.steady_focus&steady_focus_count&buff.steady_focus.remains<8
  if S.SteadyShot:IsCastable() and (S.SteadyFocus:IsAvailable() and Hunter.SteadyFocus.Count == 1 and Player:BuffRemains(S.SteadyFocusBuff) < 8) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 2"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot trickshots 4"; end
  end
  -- volley
  if S.Volley:IsCastable() then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y) then return "volley trickshots 6"; end
  end
  -- barrage,if=talent.rapid_fire_barrage&buff.trick_shots.remains>=execute_time
  if S.Barrage:IsReady() and (S.RapidFireBarrage:IsAvailable() and Player:BuffRemains(S.TrickShotsBuff) >= S.Barrage:ExecuteTime()) then
    if Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "barrage trickshots 8"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>=execute_time
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) >= S.RapidFire:ExecuteTime()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire trickshots 10"; end
  end
  -- kill_shot,if=buff.razor_fragments.up
  if S.KillShot:IsReady() and (Player:BuffUp(S.RazorFragmentsBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot trickshots 12"; end
  end
  -- black_arrow
  if S.BlackArrow:IsReady() then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow trickshots 14"; end
  end
  -- wailing_arrow,if=buff.precise_shots.down
  if S.WailingArrow:IsReady() and (Player:BuffDown(S.PreciseShotsBuff)) then
    if Cast(S.WailingArrow, Settings.Marksmanship.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow trickshots 16"; end
  end
  -- trueshot,if=variable.trueshot_ready
  if S.Trueshot:IsReady() and CDsON() and (VarTrueshotReady) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot, nil, not TargetInRange40y) then return "trueshot trickshots 18"; end
  end
  -- aimed_shot,target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99,if=buff.trick_shots.remains>=execute_time&buff.precise_shots.down
  if S.AimedShot:IsReady() and (Player:BuffRemains(S.TrickShotsBuff) >= S.AimedShot:ExecuteTime() and Player:BuffDown(S.PreciseShotsBuff)) then
    if Everyone.CastTargetIf(S.AimedShot, Enemies10ySplash, "min", EvaluateTargetIfFilterAimedShot, nil, not TargetInRange40y) then return "aimed_shot trickshots 20"; end
  end
  -- multishot,if=buff.trick_shots.down|buff.precise_shots.up|focus>cost+action.aimed_shot.cost
  if S.MultiShot:IsReady() and (Player:BuffDown(S.TrickShotsBuff) or Player:BuffUp(S.PreciseShotsBuff) or Player:FocusP() > S.MultiShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot trickshots 22"; end
  end
  -- bag_of_tricks,if=buff.trueshot.down
  if S.BagofTricks:IsReady() and (Player:BuffDown(S.Trueshot)) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks trickshots 24"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 26"; end
  end
end

local function Trinkets()
  -- variable,name=sync_ready,value=variable.trueshot_ready
  VarSyncReady = VarTrueshotReady
  -- variable,name=sync_active,value=buff.trueshot.up
  VarSyncActive = Player:BuffUp(S.TrueshotBuff)
  -- variable,name=sync_remains,value=cooldown.trueshot.remains_guess
  VarSyncRemains = S.Trueshot:CooldownRemains()
  -- use_item,use_off_gcd=1,slot=trinket1,if=trinket.1.has_use_buff&(variable.sync_ready&(variable.trinket_1_stronger|trinket.2.cooldown.remains)|!variable.sync_ready&(variable.trinket_1_stronger&(variable.sync_remains>trinket.1.cooldown.duration%3&fight_remains>trinket.1.cooldown.duration+20|trinket.2.has_use_buff&trinket.2.cooldown.remains>variable.sync_remains-15&trinket.2.cooldown.remains-5<variable.sync_remains&variable.sync_remains+45>fight_remains)|variable.trinket_2_stronger&(trinket.2.cooldown.remains&(trinket.2.cooldown.remains-5<variable.sync_remains&variable.sync_remains>=20|trinket.2.cooldown.remains-5>=variable.sync_remains&(variable.sync_remains>trinket.1.cooldown.duration%3|trinket.1.cooldown.duration<fight_remains&(variable.sync_remains+trinket.1.cooldown.duration>fight_remains)))|trinket.2.cooldown.ready&variable.sync_remains>20&variable.sync_remains<trinket.2.cooldown.duration%3)))|!trinket.1.has_use_buff&(trinket.1.cast_time=0|!variable.sync_active)&(!trinket.2.has_use_buff&(variable.trinket_1_stronger|trinket.2.cooldown.remains)|trinket.2.has_use_buff&(variable.sync_remains>20|trinket.2.cooldown.remains>20))|fight_remains<25&(variable.trinket_1_stronger|trinket.2.cooldown.remains)
  if Trinket1:IsReady() and not VarTrinket1BL and (Trinket1:HasUseBuff() and (VarSyncReady and (VarTrinket1Stronger or Trinket2:CooldownDown()) or not VarSyncReady and (VarTrinket1Stronger and (VarSyncRemains > VarTrinket1CD / 3 and FightRemains > VarTrinket1CD + 20 or Trinket2:HasUseBuff() and Trinket2:CooldownRemains() > VarSyncRemains - 15 and Trinket2:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains + 45 > FightRemains) or VarTrinket2Stronger and (Trinket2:CooldownDown() and (Trinket2:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains >= 20 or Trinket2:CooldownRemains() - 5 >= VarSyncRemains and (VarSyncRemains > VarTrinket1CD / 3 or VarTrinket1CD < FightRemains and (VarSyncRemains + VarTrinket1CD > FightRemains))) or Trinket2:CooldownUp() and VarSyncRemains > 20 and VarSyncRemains < VarTrinket2CD / 3))) or not Trinket1:HasUseBuff() and (VarTrinket1Spell:CastTime() == 0 or not VarSyncActive) and (not Trinket2:HasUseBuff() and (VarTrinket1Stronger or Trinket2:CooldownDown()) or Trinket2:HasUseBuff() and (VarSyncRemains > 20 or Trinket2:CooldownRemains() > 20)) or FightRemains < 25 and (VarTrinket1Stronger or Trinket2:CooldownDown())) then
    if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for "..Trinket1:Name().." trinkets 2"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket2,if=trinket.2.has_use_buff&(variable.sync_ready&(variable.trinket_2_stronger|trinket.1.cooldown.remains)|!variable.sync_ready&(variable.trinket_2_stronger&(variable.sync_remains>trinket.2.cooldown.duration%3&fight_remains>trinket.2.cooldown.duration+20|trinket.1.has_use_buff&trinket.1.cooldown.remains>variable.sync_remains-15&trinket.1.cooldown.remains-5<variable.sync_remains&variable.sync_remains+45>fight_remains)|variable.trinket_1_stronger&(trinket.1.cooldown.remains&(trinket.1.cooldown.remains-5<variable.sync_remains&variable.sync_remains>=20|trinket.1.cooldown.remains-5>=variable.sync_remains&(variable.sync_remains>trinket.2.cooldown.duration%3|trinket.2.cooldown.duration<fight_remains&(variable.sync_remains+trinket.2.cooldown.duration>fight_remains)))|trinket.1.cooldown.ready&variable.sync_remains>20&variable.sync_remains<trinket.1.cooldown.duration%3)))|!trinket.2.has_use_buff&(trinket.2.cast_time=0|!variable.sync_active)&(!trinket.1.has_use_buff&(variable.trinket_2_stronger|trinket.1.cooldown.remains)|trinket.1.has_use_buff&(variable.sync_remains>20|trinket.1.cooldown.remains>20))|fight_remains<25&(variable.trinket_2_stronger|trinket.1.cooldown.remains)
  if Trinket2:IsReady() and not VarTrinket2BL and (Trinket2:HasUseBuff() and (VarSyncReady and (VarTrinket2Stronger or Trinket1:CooldownDown()) or not VarSyncReady and (VarTrinket2Stronger and (VarSyncRemains > VarTrinket2CD / 3 and FightRemains > VarTrinket2CD + 20 or Trinket1:HasUseBuff() and Trinket1:CooldownRemains() > VarSyncRemains - 15 and Trinket1:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains + 45 > FightRemains) or VarTrinket1Stronger and (Trinket1:CooldownDown() and (Trinket1:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains >= 20 or Trinket1:CooldownRemains() - 5 >= VarSyncRemains and (VarSyncRemains > VarTrinket2CD / 3 or VarTrinket2CD < FightRemains and (VarSyncRemains + VarTrinket2CD > FightRemains))) or Trinket1:CooldownUp() and VarSyncRemains > 20 and VarSyncRemains < VarTrinket1CD / 3))) or not Trinket2:HasUseBuff() and (VarTrinket2Spell:CastTime() == 0 or not VarSyncActive) and (not Trinket1:HasUseBuff() and (VarTrinket2Stronger or Trinket1:CooldownDown()) or Trinket1:HasUseBuff() and (VarSyncRemains > 20 or Trinket1:CooldownRemains() > 20)) or FightRemains < 25 and (VarTrinket2Stronger or Trinket1:CooldownDown())) then
    if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for "..Trinket2:Name().." trinkets 4"; end
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
  if not S.LoneWolf:IsAvailable() and not (Player:IsMounted() or Player:IsInVehicle()) then
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
    -- variable,name=trueshot_ready,value=cooldown.trueshot.ready&(!raid_event.adds.exists&(!talent.bullseye|fight_remains>cooldown.trueshot.duration_guess+buff.trueshot.duration%2|buff.bullseye.stack=buff.bullseye.max_stack)&(!trinket.1.has_use_buff|trinket.1.cooldown.remains>30|trinket.1.cooldown.ready)&(!trinket.2.has_use_buff|trinket.2.cooldown.remains>30|trinket.2.cooldown.ready)|raid_event.adds.exists&(!raid_event.adds.up&(raid_event.adds.duration+raid_event.adds.in<25|raid_event.adds.in>60)|raid_event.adds.up&raid_event.adds.remains>10)|fight_remains<25)
    -- Note: Can't handle the raid_event conditions.
    VarTrueshotReady = S.Trueshot:CooldownUp() and Player:BuffDown(S.TrueshotBuff)
    -- auto_shot
    -- call_action_list,name=cds
    if (CDsON()) then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
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
  HR.Print("Marksmanship Hunter rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(254, APL, Init)
