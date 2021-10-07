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
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Hunter.Marksmanship;
local I = Item.Hunter.Marksmanship;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = Item(0)
local trinket2 = Item(0)
if equip[13] then
  trinket1 = Item(equip[13])
end
if equip[14] then
  trinket2 = Item(equip[14])
end

-- Rotation Var
local fightRemains

-- Enemy Range Variables
local Enemies40y
local Enemies10ySplash
local EnemiesCount10ySplash
local TargetInRange40y

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  Commons2 = HR.GUISettings.APL.Hunter.Commons2,
  Marksmanship = HR.GUISettings.APL.Hunter.Marksmanship
};

-- Variables
local VarCAExecute = Target:HealthPercentage() > 70 and S.CarefulAim:IsAvailable()
local SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
local EagletalonsTrueFocusEquipped = Player:HasLegendaryEquipped(74)
local SurgingShotsEquipped = Player:HasLegendaryEquipped(75)
local RazorFragmentsEquipped = Player:HasLegendaryEquipped(255)

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = Item(0)
  trinket2 = Item(0)
  if equip[13] then
    trinket1 = Item(equip[13])
  end
  if equip[14] then
    trinket2 = Item(equip[14])
  end
  SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
  EagletalonsTrueFocusEquipped = Player:HasLegendaryEquipped(74)
  SurgingShotsEquipped = Player:HasLegendaryEquipped(75)
  RazorFragmentsEquipped = Player:HasLegendaryEquipped(255)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.SerpentSting:RegisterInFlight()
  S.SteadyShot:RegisterInFlight()
  S.AimedShot:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.SerpentSting:RegisterInFlight()
S.SteadyShot:RegisterInFlight()
S.AimedShot:RegisterInFlight()

--Functions
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function MasterMarksmanBuffCheck()
  return (Player:BuffUp(S.MasterMarksmanBuff) or (Player:IsCasting(S.AimedShot) and S.MasterMarksman:IsAvailable()))
end

-- TODO(mrdmnd): Open issues:
-- APL seems like it could use some love in the following case:
-- 1) We sometimes suggest rapid fire immediately after an aimed shot, even in aoe,
-- when the aimed shot would consume a trickshots buff (and therefore we'd be casting a non-aoe Rapid Fire).
-- We don't want to cast an unbuffed rapid fire so we'd need to recognize this situation and cast multishot first.
-- This is because the splash tracker (very briefly) swaps us back into ST mode.
-- Note: this also can somewhat happen with an unbuffed AimedShot (accidentally swapping AOE -> ST mode)
---- This is mostly fixed (previously via checking for AimedShot casts, now via BuffRemains override), but the
---- Splash Damage timeout causing the rotation to flip back to ST still exists.
-- 2) Should do cycle-targets-if on kill shot. Recognize executable targets anywhere in combat with us.
---- Done! Used CastCycle instead of CastTargetIf, though.
-- 3) Should be more careful with focus when reaching aimed shot cap. Need to ENSURE we have enough focus avail
-- when final charge cooldown time is $CAST seconds away (or slightly less, to account for GCD). Don't be at low focus
-- when about to cap aimed shot, essentially.
-- 4) Trueshot rotation seems a bit wacky? Investigate.

-- TODO(mrdmnd) - if you're casting (aimed or rapid fire) with volley up, you actually only have trick shots for next
-- aimed shot if volley buff is still up at the end of the cast. also conceivably build in buffer here.
-- test Player:BuffRemains(S.VolleyBuff) against S.Trueshot:ExecuteTime() for more accuracy
local function TrickShotsBuffCheck()
  return (Player:BuffUp(S.TrickShotsBuff) and not Player:IsCasting(S.AimedShot) and not Player:IsChanneling(S.RapidFire)) or Player:BuffUp(S.VolleyBuff)
end

-- target_if=min:remains
local function EvaluateTargetIfFilterSerpentRemains(TargetUnit)
  return (TargetUnit:DebuffRemains(S.SerpentStingDebuff))
end
-- if=refreshable&target.time_to_die>duration
local function EvaluateTargetIfSerpentSting(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > S.SerpentStingDebuff:BaseDuration())
end
-- if=refreshable
local function EvaluateTargetIfSerpentSting2(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff))
end

local function EvaluateTargetIfFilterAimedShot(TargetUnit)
  -- target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99
  return (TargetUnit:DebuffRemains(S.SerpentStingDebuff) + num(S.SerpentSting:InFlight()) * 99)
end

local function EvaluateTargetIfAimedShot()
  -- if=buff.precise_shots.down|(buff.trueshot.up|full_recharge_time<gcd+cast_time)&(!talent.chimaera_shot|active_enemies<2)|buff.trick_shots.remains>execute_time&active_enemies>1
  -- Note: Added IsCasting check to smooth out opener when not using SteadyFocus
  return (Player:BuffDown(S.PreciseShotsBuff) or (Player:BuffUp(S.Trueshot) or S.AimedShot:FullRechargeTime() < Player:GCD() + S.AimedShot:CastTime() and not Player:IsCasting(S.AimedShot)) and ((not S.ChimaeraShot:IsAvailable()) or EnemiesCount10ySplash < 2) or Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:ExecuteTime() and EnemiesCount10ySplash > 1)
end

local function EvaluateTargetIfAimedShot2()
  -- if=buff.trick_shots.remains>=execute_time&(buff.precise_shots.down|full_recharge_time<cast_time+gcd|buff.trueshot.up)
  return (Player:BuffRemains(S.TrickShotsBuff) >= S.AimedShot:ExecuteTime() and (Player:BuffDown(S.PreciseShotsBuff) or S.AimedShot:FullRechargeTime() < S.AimedShot:CastTime() + Player:GCD() or Player:BuffUp(S.Trueshot)))
end

local function EvaluateCycleKillShot1(TargetUnit)
  return (Player:BuffDown(S.DeadEyeBuff) and TargetUnit:HealthPercentage() <= 20)
end

local function EvaluateCycleKillShot2(TargetUnit)
  return (TargetUnit:HealthPercentage() <= 20)
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- fleshcraft
    if S.Fleshcraft:IsCastable() then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft opener"; end
    end
    -- tar_trap,if=runeforge.soulforge_embers
    if S.TarTrap:IsReady() and SoulForgeEmbersEquipped then
      if Cast(S.TarTrap) then return "tar_trap soulforge_embers equipped opener"; end
    end
    -- variable,name=etf_precast,value=0
    -- double_tap,precast_time=10,if=active_enemies>1|!covenant.kyrian&!talent.volley|variable.etf_precast
    if S.DoubleTap:IsReady() and (EnemiesCount10ySplash > 1 or CovenantID ~= 1 and not S.Volley:IsAvailable()) then
      if Cast(S.DoubleTap, Settings.Marksmanship.GCDasOffGCD.DoubleTap) then return "double_tap opener"; end
    end
    -- trueshot,precast_etf_equip=1,precast_time=2,if=variable.etf_precast
    -- Note: The above line and etf_precast variable could be added as a settings option in the future
    -- aimed_shot,if=active_enemies<3&(!covenant.kyrian&!talent.volley|active_enemies<2)&!variable.etf_precast
    if S.AimedShot:IsReady() and not Player:IsCasting(S.AimedShot) and (EnemiesCount10ySplash < 3 and (CovenantID ~= 1 and (not S.Volley:IsAvailable()) or EnemiesCount10ySplash < 2)) then
      if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot opener"; end
    end
    -- steady_shot,if=active_enemies>2|(covenant.kyrian|talent.volley)&active_enemies=2|variable.etf_precast
    if S.SteadyShot:IsCastable() and (EnemiesCount10ySplash > 2 or (CovenantID == 1 or S.Volley:IsAvailable()) and EnemiesCount10ySplash == 2) then
      if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot opener"; end
    end
  end
end

local function Trinkets()
  -- variable,name=sync_up,value=buff.resonating_arrow.up|buff.trueshot.up
  -- variable,name=strong_sync_up,value=covenant.kyrian&buff.resonating_arrow.up&buff.trueshot.up|!covenant.kyrian&buff.trueshot.up
  -- variable,name=strong_sync_remains,op=setif,condition=covenant.kyrian,value=cooldown.resonating_arrow.remains<?cooldown.trueshot.remains,value_else=cooldown.trueshot.remains,if=buff.trueshot.down
  -- variable,name=strong_sync_remains,op=setif,condition=covenant.kyrian,value=cooldown.resonating_arrow.remains,value_else=cooldown.trueshot.remains,if=buff.trueshot.up
  -- variable,name=sync_remains,op=setif,condition=covenant.kyrian,value=cooldown.resonating_arrow.remains>?cooldown.trueshot.remains,value_else=cooldown.trueshot.remains
  -- use_items,slots=trinket1,if=(trinket.1.has_use_buff|covenant.kyrian&trinket.1.has_cooldown)&(variable.strong_sync_up&(!covenant.kyrian&!trinket.2.has_use_buff|covenant.kyrian&!trinket.2.has_cooldown|trinket.2.cooldown.remains|trinket.1.has_use_buff&(!trinket.2.has_use_buff|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)|trinket.1.has_cooldown&!trinket.2.has_use_buff&trinket.1.cooldown.duration>=trinket.2.cooldown.duration)|!variable.strong_sync_up&(!trinket.2.has_use_buff&(trinket.1.cooldown.duration-5<variable.sync_remains|variable.sync_remains>trinket.1.cooldown.duration%2)|trinket.2.has_use_buff&(trinket.1.has_use_buff&trinket.1.cooldown.duration>=trinket.2.cooldown.duration&(trinket.1.cooldown.duration-5<variable.sync_remains|variable.sync_remains>trinket.1.cooldown.duration%2)|(!trinket.1.has_use_buff|trinket.2.cooldown.duration>=trinket.1.cooldown.duration)&(trinket.2.cooldown.ready&trinket.2.cooldown.duration-5>variable.sync_remains&variable.sync_remains<trinket.2.cooldown.duration%2|!trinket.2.cooldown.ready&(trinket.2.cooldown.remains-5<variable.strong_sync_remains&variable.strong_sync_remains>20&(trinket.1.cooldown.duration-5<variable.sync_remains|trinket.2.cooldown.remains-5<variable.sync_remains&trinket.2.cooldown.duration-10+variable.sync_remains<variable.strong_sync_remains|variable.sync_remains>trinket.1.cooldown.duration%2|variable.sync_up)|trinket.2.cooldown.remains-5>variable.strong_sync_remains&(trinket.1.cooldown.duration-5<variable.strong_sync_remains|!trinket.1.has_use_buff&(variable.sync_remains>trinket.1.cooldown.duration%2|variable.sync_up))))))|target.time_to_die<variable.sync_remains)|!trinket.1.has_use_buff&!covenant.kyrian&(trinket.2.has_use_buff&((!variable.sync_up|trinket.2.cooldown.remains>5)&(variable.sync_remains>20|trinket.2.cooldown.remains-5>variable.sync_remains))|!trinket.2.has_use_buff&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|trinket.2.cooldown.duration>=trinket.1.cooldown.duration))
  -- use_items,slots=trinket2,if=(trinket.2.has_use_buff|covenant.kyrian&trinket.2.has_cooldown)&(variable.strong_sync_up&(!covenant.kyrian&!trinket.1.has_use_buff|covenant.kyrian&!trinket.1.has_cooldown|trinket.1.cooldown.remains|trinket.2.has_use_buff&(!trinket.1.has_use_buff|trinket.2.cooldown.duration>=trinket.1.cooldown.duration)|trinket.2.has_cooldown&!trinket.1.has_use_buff&trinket.2.cooldown.duration>=trinket.1.cooldown.duration)|!variable.strong_sync_up&(!trinket.1.has_use_buff&(trinket.2.cooldown.duration-5<variable.sync_remains|variable.sync_remains>trinket.2.cooldown.duration%2)|trinket.1.has_use_buff&(trinket.2.has_use_buff&trinket.2.cooldown.duration>=trinket.1.cooldown.duration&(trinket.2.cooldown.duration-5<variable.sync_remains|variable.sync_remains>trinket.2.cooldown.duration%2)|(!trinket.2.has_use_buff|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)&(trinket.1.cooldown.ready&trinket.1.cooldown.duration-5>variable.sync_remains&variable.sync_remains<trinket.1.cooldown.duration%2|!trinket.1.cooldown.ready&(trinket.1.cooldown.remains-5<variable.strong_sync_remains&variable.strong_sync_remains>20&(trinket.2.cooldown.duration-5<variable.sync_remains|trinket.1.cooldown.remains-5<variable.sync_remains&trinket.1.cooldown.duration-10+variable.sync_remains<variable.strong_sync_remains|variable.sync_remains>trinket.2.cooldown.duration%2|variable.sync_up)|trinket.1.cooldown.remains-5>variable.strong_sync_remains&(trinket.2.cooldown.duration-5<variable.strong_sync_remains|!trinket.2.has_use_buff&(variable.sync_remains>trinket.2.cooldown.duration%2|variable.sync_up))))))|target.time_to_die<variable.sync_remains)|!trinket.2.has_use_buff&!covenant.kyrian&(trinket.1.has_use_buff&((!variable.sync_up|trinket.1.cooldown.remains>5)&(variable.sync_remains>20|trinket.1.cooldown.remains-5>variable.sync_remains))|!trinket.1.has_use_buff&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|trinket.1.cooldown.duration>=trinket.2.cooldown.duration))
  -- Note: Currently unable to handle some of the checks in the above lines. As such, including the below fall-through.
  -- use_items,if=buff.trueshot.up|!talent.calling_the_shots.enabled|target.time_to_die<20
  if Settings.Commons.Enabled.Trinkets and (Player:BuffUp(S.Trueshot) or (not S.CallingtheShots:IsAvailable()) or Target:TimeToDie() < 20) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function Cds()
  -- berserking,if=(buff.trueshot.up&buff.resonating_arrow.up&covenant.kyrian)|(buff.trueshot.up&buff.wild_spirits.up&covenant.night_fae)|(covenant.venthyr|covenant.necrolord)&buff.trueshot.up|fight_remains<13|(covenant.kyrian&buff.resonating_arrow.up&fight_remains<73)
  if S.Berserking:IsReady() and ((Player:BuffUp(S.Trueshot) and Target:DebuffUp(S.ResonatingArrowDebuff) and CovenantID == 1) or (Player:BuffUp(S.Trueshot) and Target:DebuffUp(S.WildMarkDebuff) and CovenantID == 3) or (CovenantID == 2 or CovenantID == 4) and Player:BuffUp(S.Trueshot) or fightRemains < 13 or (CovenantID == 1 and Target:DebuffUp(S.ResonatingArrowDebuff) and fightRemains < 73)) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cds 2"; end
  end
  -- blood_fury,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<16
  if S.BloodFury:IsReady() and (Player:BuffUp(S.Trueshot) or S.Trueshot:CooldownRemains() > 30 or fightRemains < 16) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cds 4"; end
  end
  -- ancestral_call,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<16
  if S.AncestralCall:IsReady() and (Player:BuffUp(S.Trueshot) or S.Trueshot:CooldownRemains() > 30 or fightRemains < 16) then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cds 6"; end
  end
  -- fireblood,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<9
  if S.Fireblood:IsReady() and (Player:BuffUp(S.Trueshot) or S.Trueshot:CooldownRemains() > 30 or fightRemains < 9) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cds 8"; end
  end
  -- lights_judgment,if=buff.trueshot.down
  if S.LightsJudgment:IsReady() and (Player:BuffDown(S.Trueshot)) then
    if Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cds 10"; end
  end
  -- potion,if=buff.trueshot.up&(buff.bloodlust.up|target.health.pct<20)|fight_remains<26|(covenant.kyrian&buff.resonating_arrow.up&fight_remains<72)
  if I.PotionOfSpectralAgility:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.Trueshot) and (Player:BloodlustUp() or Target:HealthPercentage() < 20) or fightRemains < 26 or (CovenantID == 1 and Target:DebuffUp(S.ResonatingArrowDebuff) and fightRemains < 72)) then
    if Cast(I.PotionOfSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cds 12"; end
  end
end

local function St()
  -- steady_shot,if=talent.steady_focus&(prev_gcd.1.steady_shot&buff.steady_focus.remains<5|buff.steady_focus.down)&(buff.resonating_arrow.down|!covenant.kyrian)
  if S.SteadyShot:IsCastable() and (S.SteadyFocus:IsAvailable() and (Player:PrevGCDP(1, S.SteadyShot) and Player:BuffRemains(S.SteadyFocusBuff) < 5 or Player:BuffDown(S.SteadyFocusBuff)) and (Target:DebuffDown(S.ResonatingArrowDebuff) or CovenantID ~= 1)) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 2"; end
  end
  -- kill_shot
  if S.KillShot:IsCastable() then
    if Everyone.CastCycle(S.KillShot, Enemies40y, EvaluateCycleKillShot2, not TargetInRange40y) then return "kill_shot st 4"; end
  end
  -- Manually added: Primary target fallback for kill_shot
  if S.KillShot:IsCastable() then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot st 6"; end
  end
  -- double_tap,if=(covenant.kyrian&(cooldown.resonating_arrow.remains<gcd)|!covenant.kyrian&!covenant.night_fae|covenant.night_fae&(cooldown.wild_spirits.remains<gcd|cooldown.wild_spirits.remains>30)|fight_remains<15)&(!raid_event.adds.exists|raid_event.adds.up&(raid_event.adds.in<10&raid_event.adds.remains<3|raid_event.adds.in>cooldown|active_enemies>1)|!raid_event.adds.up&(raid_event.adds.count=1|raid_event.adds.in>cooldown))
  if S.DoubleTap:IsReady() and (CovenantID == 1 and (S.ResonatingArrow:CooldownRemains() < Player:GCD() + 0.5) or CovenantID ~= 1 and CovenantID ~= 3 or CovenantID == 3 and (S.WildSpirits:CooldownRemains() < Player:GCD() + 0.5 or S.WildSpirits:CooldownRemains() > 30) or fightRemains < 15) then
    if Cast(S.DoubleTap, Settings.Marksmanship.GCDasOffGCD.DoubleTap) then return "double_tap st 8"; end
  end
  -- flare,if=tar_trap.up&runeforge.soulforge_embers
  if S.Flare:IsReady() and not S.TarTrap:CooldownUp() and SoulForgeEmbersEquipped then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare st 10"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  if S.TarTrap:IsReady() and (SoulForgeEmbersEquipped and S.TarTrap:TimeSinceLastCast() > 60 - Player:GCD() - 0.5 and S.Flare:CooldownRemains() < Player:GCD()) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap st 12"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, nil, nil, not TargetInRange40y) then return "explosive_shot 14"; end
  end
  -- wild_spirits,if=!raid_event.adds.exists|!raid_event.adds.up&raid_event.adds.duration+raid_event.adds.in<20|raid_event.adds.up&raid_event.adds.remains>19|active_enemies>1
  if S.WildSpirits:IsReady() and CDsON() then
    if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "wild_spirits st 16"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsReady() then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "flayed_shot st 18"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsReady() and (Player:FocusP() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "dark_chakram st 20"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "a_murder_of_crows st 22"; end
  end
  -- wailing_arrow,if=cooldown.resonating_arrow.remains<gcd&(!talent.explosive_shot|buff.bloodlust.up)|!covenant.kyrian|cooldown.resonating_arrow.remains|target.time_to_die<5
  if S.WailingArrow:IsReady() and (S.ResonatingArrow:CooldownRemains() < Player:GCD() and ((not S.ExplosiveShot:IsAvailable()) or Player:BloodlustUp()) or CovenantID ~= 1 or S.ResonatingArrow:CooldownDown() or Target:TimeToDie() < 5) then
    if Cast(S.WailingArrow, Settings.Marksmanship.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow st 24"; end
  end
  -- resonating_arrow,if=(buff.double_tap.up|!talent.double_tap|fight_remains<12)&(!raid_event.adds.exists|!raid_event.adds.up&(raid_event.adds.duration+raid_event.adds.in<10|raid_event.adds.count=1)|raid_event.adds.up&raid_event.adds.remains>9|active_enemies>1)
  if S.ResonatingArrow:IsReady() and CDsON() and (Player:BuffUp(S.DoubleTap) or (not S.DoubleTap:IsAvailable()) or fightRemains < 12) then
    if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "resonating_arrow st 26"; end
  end
  -- volley,if=buff.resonating_arrow.up|!covenant.kyrian&(buff.precise_shots.down|!talent.chimaera_shot|active_enemies<2)
  if S.Volley:IsReady() and (Target:DebuffUp(S.ResonatingArrowDebuff) or CovenantID ~= 1 and (Player:BuffDown(S.PreciseShotsBuff) or (not S.ChimaeraShot:IsAvailable()) or EnemiesCount10ySplash < 2)) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley st 28"; end
  end
  -- steady_shot,if=covenant.kyrian&focus+cast_regen<focus.max&((cooldown.resonating_arrow.remains<gcd*3&(!soulbind.effusive_anima_accelerator|!talent.double_tap))|talent.double_tap&cooldown.double_tap.remains<3)
  if S.SteadyShot:IsCastable() and (CovenantID == 1 and Player:FocusP() + Player:FocusCastRegen(S.SteadyShot:ExecuteTime()) < Player:FocusMax() and ((S.ResonatingArrow:CooldownRemains() < Player:GCD() * 3 and ((not S.EffusiveAnimaAccelerator:IsAvailable()) or not S.DoubleTap:IsAvailable())) or S.DoubleTap:IsAvailable() and S.DoubleTap:CooldownRemains() < 3)) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 30"; end
  end
  -- trueshot,if=buff.precise_shots.down&(covenant.venthyr|covenant.necrolord|talent.calling_the_shots)|buff.resonating_arrow.up|buff.wild_spirits.up|buff.volley.up&active_enemies>1|fight_remains<25
  if S.Trueshot:IsReady() and CDsON() and (Player:BuffDown(S.PreciseShotsBuff) and (CovenantID == 2 or CovenantID == 4 or S.CallingtheShots:IsAvailable()) or Target:DebuffUp(S.ResonatingArrowDebuff) or Target:DebuffUp(S.WildMarkDebuff) or Player:BuffUp(S.VolleyBuff) and EnemiesCount10ySplash > 1 or fightRemains < 25) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot st 32"; end
  end
  -- rapid_fire,if=runeforge.surging_shots&talent.streamline&(cooldown.resonating_arrow.remains>10|!covenant.kyrian|!talent.double_tap|soulbind.effusive_anima_accelerator)
  if S.RapidFire:IsCastable() and (SurgingShotsEquipped and S.Streamline:IsAvailable() and (S.ResonatingArrow:CooldownRemains() > 10 or CovenantID ~= 1 or (not S.DoubleTap:IsAvailable()) or S.EffusiveAnimaAccelerator:IsAvailable())) then
    if Cast(S.RapidFire, nil, nil, not TargetInRange40y) then return "rapid_fire st 34"; end
  end
  -- aimed_shot,target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99,if=buff.precise_shots.down|(buff.trueshot.up|full_recharge_time<gcd+cast_time)&(!talent.chimaera_shot|active_enemies<2)|buff.trick_shots.remains>execute_time&active_enemies>1
  if S.AimedShot:IsReady() then
    if Everyone.CastTargetIf(S.AimedShot, Enemies40y, "min", EvaluateTargetIfFilterAimedShot, EvaluateTargetIfAimedShot, not TargetInRange40y) then return "aimed_shot st 36"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsCastable() and (Player:FocusP() + Player:FocusCastRegen(S.DeathChakram) < Player:FocusMax()) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "death_chakram st 38"; end
  end
  -- rapid_fire,if=(cooldown.resonating_arrow.remains>10|!covenant.kyrian|!talent.double_tap|soulbind.effusive_anima_accelerator)&focus+cast_regen<focus.max&(buff.double_tap.down&buff.eagletalons_true_focus.down|talent.streamline)
  if S.RapidFire:IsCastable() and ((S.ResonatingArrow:CooldownRemains() > 10 or CovenantID ~= 1 or (not S.DoubleTap:IsAvailable()) or S.EffusiveAnimaAccelerator:SoulbindEnabled()) and Player:FocusP() + Player:FocusCastRegen(S.RapidFire:ExecuteTime()) < Player:FocusMax() and (Player:BuffDown(S.DoubleTap) and Player:BuffDown(S.EagletalonsTrueFocusBuff) or S.Streamline:IsAvailable())) then
    if Cast(S.RapidFire, nil, nil, not TargetInRange40y) then return "rapid_fire st 40"; end
  end
  -- chimaera_shot,if=buff.precise_shots.up|focus>cost+action.aimed_shot.cost
  if S.ChimaeraShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) or Player:FocusP() > S.ChimaeraShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "chimaera_shot st 42"; end
  end
  -- arcane_shot,if=buff.precise_shots.up|focus>cost+action.aimed_shot.cost
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) or Player:FocusP() > S.ArcaneShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.ArcaneShot, nil, nil, not TargetInRange40y) then return "arcane_shot st 44"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable&target.time_to_die>duration
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, Enemies40y, "min", EvaluateTargetIfFilterSerpentRemains, EvaluateTargetIfSerpentSting, not TargetInRange40y) then return "serpent_sting st 46"; end
  end
  -- barrage,if=active_enemies>1
  if S.Barrage:IsReady() and (EnemiesCount10ySplash > 1) then
    if Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "barrage st 48"; end
  end
  -- rapid_fire,if=(cooldown.resonating_arrow.remains>10&runeforge.surging_shots|!covenant.kyrian|!talent.double_tap|soulbind.effusive_anima_accelerator)&focus+cast_regen<focus.max&(buff.double_tap.down|talent.streamline)
  if S.RapidFire:IsCastable() and ((S.ResonatingArrow:CooldownRemains() > 10 and SurgingShotsEquipped or CovenantID ~= 1 or (not S.DoubleTap:IsAvailable()) or S.EffusiveAnimaAccelerator:SoulbindEnabled()) and Player:FocusP() + Player:FocusCastRegen(S.RapidFire:ExecuteTime()) < Player:FocusMax() and (Player:BuffDown(S.DoubleTap) or S.Streamline:IsAvailable())) then
    if Cast(S.RapidFire, nil, nil, not TargetInRange40y) then return "rapid_fire st 50"; end
  end
  -- bag_of_tricks,if=buff.trueshot.down
  if S.BagofTricks:IsReady() then
    if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks st 52"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption&buff.trueshot.down
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() and Player:BuffDown(S.Trueshot)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft st 54"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 56"; end
  end
end

local function Trickshots()
  -- steady_shot,if=talent.steady_focus&in_flight&buff.steady_focus.remains<5
  if S.SteadyShot:IsCastable() and (S.SteadyFocus:IsAvailable() and S.SteadyShot:InFlight() and Player:BuffRemains(S.SteadyFocusBuff) < 5) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 2"; end
  end
  -- kill_shot,if=runeforge.pouch_of_razor_fragments&buff.flayers_mark.up
  if S.KillShot:IsCastable() and (RazorFragmentsEquipped and Player:BuffUp(S.FlayersMark)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot trickshots 4"; end
  end
  -- flayed_shot,if=runeforge.pouch_of_razor_fragments
  if S.FlayedShot:IsCastable() and (RazorFragmentsEquipped) then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "flayed_shot trickshots 6"; end
  end
  -- double_tap,if=(covenant.kyrian&cooldown.resonating_arrow.remains<gcd|!covenant.kyrian&!covenant.night_fae|covenant.night_fae&(cooldown.wild_spirits.remains<gcd|cooldown.wild_spirits.remains>30)|target.time_to_die<10|cooldown.resonating_arrow.remains>10&active_enemies>3)&(!raid_event.adds.exists|raid_event.adds.remains>9|!covenant.kyrian)
  if S.DoubleTap:IsReady() and (CovenantID == 1 and S.ResonatingArrow:CooldownRemains() < Player:GCD() + 0.5 or CovenantID ~= 1 and CovenantID ~= 3 or CovenantID == 3 and (S.WildSpirits:CooldownRemains() < Player:GCD() + 0.5 or S.WildSpirits:CooldownRemains() > 30) or Target:TimeToDie() < 10 or S.ResonatingArrow:CooldownRemains() > 10 and EnemiesCount10ySplash > 3) then
    if Cast(S.DoubleTap, Settings.Marksmanship.GCDasOffGCD.DoubleTap) then return "double_tap trickshots 8"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equippeds&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  if S.TarTrap:IsReady() and (SoulForgeEmbersEquipped and S.TarTrap:TimeSinceLastCast() > 60 - Player:GCD() - 0.5 and S.Flare:CooldownRemains() < Player:GCD()) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap trickshots 10"; end
  end
  -- flare,if=tar_trap.up&runeforge.soulforge_embers
  if S.Flare:IsReady() and not S.TarTrap:CooldownUp() and SoulForgeEmbersEquipped then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare trickshots 12"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, nil, nil, not TargetInRange40y) then return "explosive_shot trickshots 14"; end
  end
  -- wild_spirits,if=!raid_event.adds.exists|raid_event.adds.remains>10|active_enemies>=raid_event.adds.count*2
  if S.WildSpirits:IsReady() and CDsON() then
    if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "wild_spirits trickshots 16"; end
  end
  -- wailing_arrow,if=cooldown.resonating_arrow.remains<gcd&(!talent.explosive_shot|buff.bloodlust.up)|!covenant.kyrian|cooldown.resonating_arrow.remains>10|target.time_to_die<5
  if S.WailingArrow:IsReady() and (S.ResonatingArrow:CooldownRemains() < Player:GCD() and ((not S.ExplosiveShot:IsAvailable()) or Player:BloodlustUp()) or CovenantID ~= 1 or S.ResonatingArrow:CooldownRemains() > 10 or Target:TimeToDie() < 5) then
    if Cast(S.WailingArrow, Settings.Marksmanship.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow trickshots 18"; end
  end
  -- resonating_arrow,if=(cooldown.volley.remains<gcd|!talent.volley|target.time_to_die<12)&(!raid_event.adds.exists|raid_event.adds.remains>9|active_enemies>=raid_event.adds.count*2)
  if S.ResonatingArrow:IsReady() and CDsON() and (S.Volley:CooldownRemains() < Player:GCD() or (not S.Volley:IsAvailable()) or Target:TimeToDie() < 12) then
    if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant) then return "resonating_arrow trickshots 20"; end
  end
  -- volley,if=buff.resonating_arrow.up|!covenant.kyrian
  if S.Volley:IsReady() and (Target:DebuffUp(S.ResonatingArrowDebuff) or CovenantID ~= 1) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley)  then return "volley trickshots 22"; end
  end
  -- barrage
  if S.Barrage:IsReady() then
    if Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "barrage trickshots 24"; end
  end
  -- trueshot,if=buff.resonating_arrow.up|cooldown.resonating_arrow.remains>10|!covenant.kyrian|target.time_to_die<20
  if S.Trueshot:IsReady() and CDsON() and (Target:DebuffUp(S.ResonatingArrowDebuff) or S.ResonatingArrow:CooldownRemains() > 10 or CovenantID ~= 1 or Target:TimeToDie() < 20) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot, nil, not TargetInRange40y) then return "trueshot trickshots 26"; end
  end
  -- rapid_fire,if=runeforge.surging_shots&(cooldown.resonating_arrow.remains>10|!covenant.kyrian|!talent.double_tap)&buff.trick_shots.remains>=execute_time
  if S.RapidFire:IsCastable() and (SurgingShotsEquipped and (S.ResonatingArrow:CooldownRemains() > 10 or CovenantID ~= 1 or not S.DoubleTap:IsAvailable()) and Player:BuffRemains(S.TrickShotsBuff) >= S.RapidFire:ExecuteTime()) then
    if Cast(S.RapidFire, nil, nil, not TargetInRange40y) then return "rapid_fire trickshots 28"; end
  end
  -- aimed_shot,target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99,if=buff.trick_shots.remains>=execute_time&(buff.precise_shots.down|full_recharge_time<cast_time+gcd|buff.trueshot.up)
  if S.AimedShot:IsReady() then
    if Everyone.CastTargetIf(S.AimedShot, Enemies40y, "min", EvaluateTargetIfFilterAimedShot, EvaluateTargetIfAimedShot2, not TargetInRange40y) then return "aimed_shot trickshots 30"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsReady() and (Player:FocusP() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant) then return "dark_chakram trickshots 32"; end
  end
  -- rapid_fire,if=(cooldown.resonating_arrow.remains>10&runeforge.surging_shots|!covenant.kyrian|!runeforge.surging_shots|!talent.double_tap)&buff.trick_shots.remains>=execute_time
  if S.RapidFire:IsCastable() and ((S.ResonatingArrow:CooldownRemains() > 10 and SurgingShotsEquipped or CovenantID ~= 1 or (not SurgingShotsEquipped) or not S.DoubleTap:IsAvailable()) and Player:BuffRemains(S.TrickShotsBuff) >= S.RapidFire:ExecuteTime()) then
    if Cast(S.RapidFire, nil, nil, not TargetInRange40y) then return "rapid_fire trickshots 34"; end
  end
  -- multishot,if=buff.trick_shots.down|buff.precise_shots.up&focus>cost+action.aimed_shot.cost&(!talent.chimaera_shot|active_enemies>3)
  if S.Multishot:IsReady() and ((not TrickShotsBuffCheck()) or Player:BuffUp(S.PreciseShotsBuff) and Player:FocusP() > S.Multishot:Cost() + S.AimedShot:Cost() and ((not S.ChimaeraShot:IsAvailable()) or EnemiesCount10ySplash > 3)) then
    if Cast(S.Multishot, nil, nil, not TargetInRange40y) then return "multishot trickshots 36"; end
  end
  -- chimaera_shot,if=buff.precise_shots.up&focus>cost+action.aimed_shot.cost&active_enemies<4
  if S.ChimaeraShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and Player:FocusP() > S.ChimaeraShot:Cost() + S.AimedShot:Cost() and EnemiesCount10ySplash < 4) then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "chimaera_shot trickshots 38"; end
  end
  -- kill_shot,if=buff.dead_eye.down
  if S.KillShot:IsCastable() then
    if Everyone.CastCycle(S.KillShot, Enemies40y, EvaluateCycleKillShot1, not TargetInRange40y) then return "kill_shot trickshots 40"; end
  end
  -- Manually added: Primary target fallback for kill_shot
  if S.KillShot:IsCastable() and (Player:BuffDown(S.DeadEyeBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot trickshots 42"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "a_murder_of_crows trickshots 44"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsReady() then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant) then return "flayed_shot trickshots 46"; end
  end
  -- serpent_sting,target_if=min:dot.serpent_sting.remains,if=refreshable
  if S.SerpentSting:IsReady()  then
    if Everyone.CastTargetIf(S.SerpentSting, Enemies40y, "min", EvaluateTargetIfFilterSerpentRemains, EvaluateTargetIfSerpentSting2, not TargetInRange40y) then return "serpent_sting trickshots 48"; end
  end
  -- multishot,if=focus>cost+action.aimed_shot.cost&(cooldown.resonating_arrow.remains>5|!covenant.kyrian)
  if S.Multishot:IsReady() and (Player:FocusP() > S.Multishot:Cost() + S.AimedShot:Cost() and (S.ResonatingArrow:CooldownRemains() > 5 or CovenantID ~= 1)) then
    if Cast(S.Multishot, nil, nil, not TargetInRange40y) then return "multishot trickshots 50"; end
  end
  -- tar_trap,if=runeforge.nessingwarys_trapping_apparatus
  -- freezing_trap,if=runeforge.nessingwarys_trapping_apparatus
  -- bag_of_tricks,if=buff.trueshot.down
  if S.BagofTricks:IsReady() and (Player:BuffDown(S.Trueshot)) then
    if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks trickshots 52"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption&buff.trueshot.down
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() and Player:BuffDown(S.Trueshot)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft trickshots 54"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 56"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  TargetInRange40y = Target:IsSpellInRange(S.AimedShot) -- Ranged abilities; Distance varies by Mastery
  Enemies40y = Player:GetEnemiesInRange(S.AimedShot.MaximumRange)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesCount10ySplash = #Enemies10ySplash
  else
    EnemiesCount10ySplash = 1
  end

  -- Calculate fight_remains
  fightRemains = HL.FightRemains(Enemies10ySplash, false)

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Self heal, if below setting value
    if S.Exhilaration:IsReady() and Player:HealthPercentage() <= Settings.Commons2.ExhilarationHP then
      if Cast(S.Exhilaration, Settings.Commons2.GCDasOffGCD.Exhilaration) then return "exhilaration"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(40, S.CounterShot, Settings.Commons2.OffGCDasOffGCD.CounterShot, false); if ShouldReturn then return ShouldReturn; end
    -- auto_shot
    -- counter_shot,line_cd=30,if=runeforge.sephuzs_proclamation|soulbind.niyas_tools_poison|(conduit.reversal_of_fortune&!runeforge.sephuzs_proclamation)
    -- Interrupts handled above
    -- call_action_list,name=trinkets,if=covenant.kyrian&cooldown.trueshot.remains&cooldown.resonating_arrow.remains|!covenant.kyrian&cooldown.trueshot.remains
    if (Settings.Commons.Enabled.Trinkets and (CovenantID == 1 and not S.Trueshot:CooldownUp() and (not S.ResonatingArrow:CooldownUp()) or CovenantID ~= 1 and not S.Trueshot:CooldownUp())) then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- newfound_resolve,if=soulbind.newfound_resolve&(buff.resonating_arrow.up|cooldown.resonating_arrow.remains>10|fight_remains<16
    -- APL Comment: Delay facing your doubt until you have put Resonating Arrow down, or if the cooldown is too long to delay facing your Doubt. If none of these conditions are able to met within the 10 seconds leeway, the sim faces your Doubt automatically.
    -- call_action_list,name=cds
    if (CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3
    if (EnemiesCount10ySplash < 3) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trickshots,if=active_enemies>2
    if (EnemiesCount10ySplash > 2) then
      local ShouldReturn = Trickshots(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool Focus if nothing else to do
    if Cast(S.PoolFocus) then return "Pooling Focus"; end
  end
end

local function Init()
  HR.Print("Marksmanship Hunter rotation is currently a work in progress, but has been updated for patch 9.1.")
end

HR.SetAPL(254, APL, Init)
