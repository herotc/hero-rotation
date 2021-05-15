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
local Trinket1HasUseBuff = (trinket1:IsEquippedAndReady() or trinket1:CooldownRemains() > 0)
local Trinket2HasUseBuff = (trinket2:IsEquippedAndReady() or trinket2:CooldownRemains() > 0)

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- Enemy Range Variables
local Enemies40y
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
  Trinket1HasUseBuff = (trinket1:IsEquippedAndReady() or trinket1:CooldownRemains() > 0)
  Trinket2HasUseBuff = (trinket2:IsEquippedAndReady() or trinket2:CooldownRemains() > 0)
  SoulForgeEmbersEquipped = Player:HasLegendaryEquipped(68)
  EagletalonsTrueFocusEquipped = Player:HasLegendaryEquipped(74)
  SurgingShotsEquipped = Player:HasLegendaryEquipped(75)
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

-- target_if=min:remains,if=refreshable&target.time_to_die>duration
local function EvaluateTargetIfFilterSerpentRemains(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > S.SerpentStingDebuff:BaseDuration())
end
local function EvaluateTargetIfSerpentSting(TargetUnit)
  return (TargetUnit:TimeToDie() > S.SerpentStingDebuff:BaseDuration())
end

local function EvaluateTargetIfFilterAimedShot(TargetUnit)
  -- target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99
  return (TargetUnit:DebuffRemains(S.SerpentStingDebuff) + num(S.SerpentSting:InFlight()) * 99)
end

local function EvaluateTargetIfAimedShot()
  -- if=buff.precise_shots.down|(buff.trueshot.up|full_recharge_time<gcd+cast_time)&(!talent.chimaera_shot|active_enemies<2)|buff.trick_shots.remains>execute_time&active_enemies>1
  -- Note: Added IsCasting check to smooth out opener when not using SteadyFocus
  return (Player:BuffDown(S.PreciseShotsBuff) or (Player:BuffUp(S.Trueshot) or S.AimedShot:FullRechargeTime() < Player:GCD() + S.AimedShot:CastTime() and not Player:IsCasting(S.AimedShot)) and (not S.ChimaeraShot:IsAvailable() or EnemiesCount10ySplash < 2) or Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:ExecuteTime() and EnemiesCount10ySplash > 1)
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
    -- tar_trap,if=runeforge.soulforge_embers.equipped
    if S.TarTrap:IsReady() and SoulForgeEmbersEquipped then
      if Cast(S.TarTrap) then return "tar_trap soulforge_embers equipped opener"; end
    end
    -- double_tap,precast_time=10,if=active_enemies>1|!covenant.kyrian&!talent.volley
    if S.DoubleTap:IsReady() and (EnemiesCount10ySplash > 1 or Player:Covenant() ~= "Kyrian" and not S.Volley:IsAvailable()) then
      if Cast(S.DoubleTap, Settings.Marksmanship.GCDasOffGCD.DoubleTap) then return "double_tap opener"; end
    end
    -- aimed_shot,if=active_enemies<3&(!covenant.kyrian&!talent.volley|active_enemies<2)
    if S.AimedShot:IsReady() and not (Player:IsCasting(S.AimedShot) or S.AimedShot:InFlight()) and (EnemiesCount10ySplash < 3 and (Player:Covenant() ~= "Kyrian" and not S.Volley:IsAvailable() or EnemiesCount10ySplash < 2)) then
      if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot opener"; end
    end
    -- steady_shot,if=active_enemies>2|(covenant.kyrian|talent.volley)&active_enemies=2
    if S.SteadyShot:IsCastable() and (EnemiesCount10ySplash > 2 or (Player:Covenant() == "Kyrian" or S.Volley:IsAvailable()) and EnemiesCount10ySplash == 2) then
      if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot opener"; end
    end
  end
end

local function Cds()
  -- berserking,if=buff.trueshot.up|target.time_to_die<13
  if S.Berserking:IsReady() and (Player:BuffUp(S.Trueshot) or Target:TimeToDie() < 13) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cds 2"; end
  end
  -- blood_fury,if=buff.trueshot.up|target.time_to_die<16
  if S.BloodFury:IsReady() and (Player:BuffUp(S.Trueshot) or Target:TimeToDie() < 16) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cds 4"; end
  end
  -- ancestral_call,if=buff.trueshot.up|target.time_to_die<16
  if S.AncestralCall:IsReady() and (Player:BuffUp(S.Trueshot) or Target:TimeToDie() < 16) then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cds 6"; end
  end
  -- fireblood,if=buff.trueshot.up|target.time_to_die<9
  if S.Fireblood:IsReady() and (Player:BuffUp(S.Trueshot) or Target:TimeToDie() < 9) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cds 8"; end
  end
  -- lights_judgment,if=buff.trueshot.down
  if S.LightsJudgment:IsReady() and (Player:BuffDown(S.Trueshot)) then
    if Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cds 10"; end
  end
  -- bag_of_tricks,if=buff.trueshot.down
  if S.BagofTricks:IsReady() then
    if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cds 12"; end
  end
  -- potion,if=buff.trueshot.up&buff.bloodlust.up|buff.trueshot.up&target.health.pct<20|target.time_to_die<26
  if I.PotionOfSpectralAgility:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.Trueshot) and Player:BloodlustUp() or Player:BuffUp(S.Trueshot) and Target:HealthPercentage() < 20 or Target:TimeToDie() < 26) then
    if Cast(I.PotionOfSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cds 14"; end
  end
end

local function St()
  -- steady_shot,if=talent.steady_focus&(prev_gcd.1.steady_shot&buff.steady_focus.remains<5|buff.steady_focus.down)
  if S.SteadyShot:IsCastable() and (S.SteadyFocus:IsAvailable() and (Player:PrevGCDP(1, S.SteadyShot) and Player:BuffRemains(S.SteadyFocusBuff) < 5 or Player:BuffDown(S.SteadyFocusBuff))) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 2"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() then
    if Everyone.CastCycle(S.KillShot, Enemies40y, EvaluateCycleKillShot2, not TargetInRange40y) then return "kill_shot st 4"; end
  end
  -- Manually added: Primary target fallback for kill_shot
  if S.KillShot:IsCastable() then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot st 5"; end
  end
  -- double_tap,if=covenant.kyrian&cooldown.resonating_arrow.remains<gcd|!covenant.kyrian&!covenant.night_fae|covenant.night_fae&(cooldown.wild_spirits.remains<gcd|cooldown.trueshot.remains>55)|target.time_to_die<15
  if S.DoubleTap:IsReady() and (Player:Covenant() == "Kyrian" and S.ResonatingArrow:CooldownRemains() < Player:GCD() + 0.5 or Player:Covenant() ~= "Kyrian" and Player:Covenant() ~= "Night Fae" or Player:Covenant() == "Night Fae" and (S.WildSpirits:CooldownRemains() < Player:GCD() + 0.5 or S.Trueshot:CooldownRemains() > 55) or Target:TimeToDie() < 15) then
    if Cast(S.DoubleTap, Settings.Marksmanship.GCDasOffGCD.DoubleTap) then return "double_tap st 6"; end
  end
  -- flare,if=tar_trap.up&runeforge.soulforge_embers
  if S.Flare:IsReady() and not S.TarTrap:CooldownUp() and SoulForgeEmbersEquipped then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare st 8"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  if S.TarTrap:IsReady() and (SoulForgeEmbersEquipped and S.TarTrap:TimeSinceLastCast() > 60 - Player:GCD() - 0.5 and S.Flare:CooldownRemains() < Player:GCD()) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap soulforge_embers equipped st 10"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, nil, nil, not TargetInRange40y) then return "explosive_shot 12"; end
  end
  -- wild_spirits
  if S.WildSpirits:IsReady() and CDsON() then
    if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "wild_spirits st 14"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsReady() then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "flayed_shot st 16"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsReady() and (Player:FocusP() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "dark_chakram st 18"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "a_murder_of_crows st 20"; end
  end
  -- resonating_arrow
  if S.ResonatingArrow:IsReady() then
    if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInRange40y) then return "resonating_arrow st 22"; end
  end
  -- volley,if=buff.precise_shots.down|!talent.chimaera_shot|active_enemies<2
  if S.Volley:IsReady() and (Player:BuffDown(S.PreciseShotsBuff) or not S.ChimaeraShot:IsAvailable() or EnemiesCount10ySplash < 2) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley st 24 "; end
  end
  -- trueshot,if=buff.precise_shots.down|buff.resonating_arrow.up|buff.wild_spirits.up|buff.volley.up&active_enemies>1
  if S.Trueshot:IsReady() and CDsON() and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.ResonatingArrowDebuff) or Target:DebuffUp(S.WildMarkDebuff) or EnemiesCount10ySplash > 1) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot st 26"; end
  end
  -- aimed_shot,target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99,if=buff.precise_shots.down|(buff.trueshot.up|full_recharge_time<gcd+cast_time)&(!talent.chimaera_shot|active_enemies<2)|buff.trick_shots.remains>execute_time&active_enemies>1
  if S.AimedShot:IsReady() then
    if Everyone.CastTargetIf(S.AimedShot, Enemies40y, "min", EvaluateTargetIfFilterAimedShot, EvaluateTargetIfAimedShot, not TargetInRange40y) then return "aimed_shot st 28"; end
  end
  -- rapid_fire,if=focus+cast_regen<focus.max&(buff.trueshot.down|!runeforge.eagletalons_true_focus)&(buff.double_tap.down|talent.streamline)
  if S.RapidFire:IsCastable() and (Player:FocusP() + Player:FocusCastRegen(S.RapidFire:CastTime()) < Player:FocusMax() and (Player:BuffDown(S.Trueshot) or not EagletalonsTrueFocusEquipped) and (Player:BuffDown(S.DoubleTap) or S.Streamline:IsAvailable())) then
    if Cast(S.RapidFire, nil, nil, not TargetInRange40y) then return "rapid_fire st 30"; end
  end
  -- chimaera_shot,if=buff.precise_shots.up|focus>cost+action.aimed_shot.cost
  if S.ChimaeraShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) or Player:FocusP() > S.ChimaeraShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "chimaera_shot st 32"; end
  end
  -- arcane_shot,if=buff.precise_shots.up|focus>cost+action.aimed_shot.cost
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) or Player:FocusP() > S.ArcaneShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.ArcaneShot, nil, nil, not TargetInRange40y) then return "arcane_shot st 34"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable&target.time_to_die>duration
  if S.SerpentSting:IsReady() then
    if Everyone.CastCycle(S.SerpentSting, Enemies40y, EvaluateTargetIfFilterSerpentRemains, not TargetInRange40y) then return "serpent_sting st 36"; end
  end
  -- barrage,if=active_enemies>1
  if S.Barrage:IsReady() and (EnemiesCount10ySplash > 1) then
    if Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "barrage st 38"; end
  end
  -- rapid_fire,if=focus+cast_regen<focus.max&(buff.double_tap.down|talent.streamline)
  if S.RapidFire:IsCastable() and (Player:FocusP() + Player:FocusCastRegen(S.RapidFire:CastTime()) < Player:FocusMax() and (Player:BuffDown(S.DoubleTap) or S.Streamline:IsAvailable())) then
    if Cast(S.RapidFire, nil, nil, not TargetInRange40y) then return "rapid_fire st 40"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 42"; end
  end
end

local function Trickshots()
  -- steady_shot,if=talent.steady_focus&in_flight&buff.steady_focus.remains<5
  if S.SteadyShot:IsCastable() and (S.SteadyFocus:IsAvailable() and S.SteadyShot:InFlight() and Player:BuffRemains(S.SteadyFocusBuff) < 5) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 2"; end
  end
  -- double_tap,if=covenant.kyrian&cooldown.resonating_arrow.remains<gcd|!covenant.kyrian&!covenant.night_fae|covenant.night_fae&(cooldown.wild_spirits.remains<gcd|cooldown.trueshot.remains>55)|target.time_to_die<10
  if S.DoubleTap:IsReady() and (Player:Covenant() == "Kyrian" and S.ResonatingArrow:CooldownRemains() < Player:GCD() + 0.5 or Player:Covenant() ~= "Kyrian" and Player:Covenant() ~= "Night Fae" or Player:Covenant() == "Night Fae" and (S.WildSpirits:CooldownRemains() < Player:GCD() + 0.5 or S.Trueshot:CooldownRemains() > 55) or Target:TimeToDie() < 10) then
    if Cast(S.DoubleTap, Settings.Marksmanship.GCDasOffGCD.DoubleTap) then return "double_tap trickshots 4"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equippeds&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  if S.TarTrap:IsReady() and (SoulForgeEmbersEquipped and S.TarTrap:TimeSinceLastCast() > 60 - Player:GCD() - 0.5 and S.Flare:CooldownRemains() < Player:GCD()) then
    if Cast(S.TarTrap, Settings.Commons2.GCDasOffGCD.TarTrap, nil, not Target:IsInRange(40)) then return "tar_trap soulforge_embers equipped trickshots 6"; end
  end
  -- flare,if=tar_trap.up&runeforge.soulforge_embers
  if S.Flare:IsReady() and not S.TarTrap:CooldownUp() and SoulForgeEmbersEquipped then
    if Cast(S.Flare, Settings.Commons2.GCDasOffGCD.Flare) then return "flare trickshots 8"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, nil, nil, not TargetInRange40y) then return "explosive_shot trickshots 10"; end
  end
  -- wild_spirits
  if S.WildSpirits:IsReady() and CDsON() then
    if Cast(S.WildSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "wild_spirits trickshots 12 "; end
  end
  -- resonating_arrow
  if S.ResonatingArrow:IsReady() then
    if Cast(S.ResonatingArrow, nil, Settings.Commons.DisplayStyle.Covenant) then return "resonating_arrow trickshots 14"; end
  end
  -- volley
  if S.Volley:IsReady() then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley)  then return "volley trickshots 16"; end
  end
  -- barrage
  if S.Barrage:IsReady() then
    if Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "barrage trickshots 18"; end
  end
  -- trueshot
  if S.Trueshot:IsReady() and CDsON() then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot, nil, not TargetInRange40y) then return "trueshot trickshots 20"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>=execute_time&runeforge.surging_shots&buff.double_tap.down
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) >= S.RapidFire:ExecuteTime() and SurgingShotsEquipped and Player:BuffDown(S.DoubleTap)) then
    if Cast(S.RapidFire, nil, nil, not TargetInRange40y) then return "rapid_fire trickshots 22"; end
  end
  -- aimed_shot,target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99,if=buff.trick_shots.remains>=execute_time&(buff.precise_shots.down|full_recharge_time<cast_time+gcd|buff.trueshot.up)
  if S.AimedShot:IsReady() then
    if Everyone.CastTargetIf(S.AimedShot, Enemies40y, "min", EvaluateTargetIfFilterAimedShot, EvaluateTargetIfAimedShot2, not TargetInRange40y) then return "aimed_shot trickshots 24"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsReady() and (Player:FocusP() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if Cast(S.DeathChakram, nil, Settings.Commons.DisplayStyle.Covenant) then return "dark_chakram trickshots 26"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>=execute_time
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) >= S.RapidFire:ExecuteTime()) then
    if Cast(S.RapidFire, nil, nil, not TargetInRange40y) then return "rapid_fire trickshots 28"; end
  end
  -- multishot,if=buff.trick_shots.down|buff.precise_shots.up&focus>cost+action.aimed_shot.cost&(!talent.chimaera_shot|active_enemies>3)
  if S.Multishot:IsReady() and (not TrickShotsBuffCheck() or Player:BuffUp(S.PreciseShotsBuff) and Player:FocusP() > S.Multishot:Cost() + S.AimedShot:Cost() and (not S.ChimaeraShot:IsAvailable() or EnemiesCount10ySplash > 3)) then
    if Cast(S.Multishot, nil, nil, not TargetInRange40y) then return "multishot trickshots 30"; end
  end
  -- chimaera_shot,if=buff.precise_shots.up&focus>cost+action.aimed_shot.cost&active_enemies<4
  if S.ChimaeraShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and Player:FocusP() > S.ChimaeraShot:Cost() + S.AimedShot:Cost() and EnemiesCount10ySplash < 4) then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "chimaera_shot trickshots 32"; end
  end
  -- kill_shot,if=buff.dead_eye.down
  if S.KillShot:IsReady() then
    if Everyone.CastCycle(S.KillShot, Enemies40y, EvaluateCycleKillShot1, not TargetInRange40y) then return "kill_shot trickshots 34"; end
  end
  -- Manually added: Primary target fallback for kill_shot
  if S.KillShot:IsCastable() and (Player:BuffDown(S.DeadEyeBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot trickshots 35"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if Cast(S.AMurderofCrows, Settings.Commons.GCDasOffGCD.AMurderofCrows, nil, not TargetInRange40y) then return "a_murder_of_crows trickshots 36"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsReady() then
    if Cast(S.FlayedShot, nil, Settings.Commons.DisplayStyle.Covenant) then return "flayed_shot trickshots 38"; end
  end
  -- serpent_sting,target_if=min:dot.serpent_sting.remains,if=refreshable
  if S.SerpentSting:IsReady()  then
    if Everyone.CastCycle(S.SerpentSting, Enemies40y, EvaluateTargetIfFilterSerpentRemains, not TargetInRange40y) then return "serpent_sting trickshots 40"; end
  end
  -- multishot,if=focus>cost+action.aimed_shot.cost
  if S.Multishot:IsReady() and (Player:FocusP() > S.Multishot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.Multishot, nil, nil, not TargetInRange40y) then return "multishot trickshots 42"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 44"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies40y = Player:GetEnemiesInRange(S.AimedShot.MaximumRange)
  TargetInRange40y = Target:IsSpellInRange(S.AimedShot) -- Ranged abilities; Distance varies by Mastery
  if AoEON() then
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10) -- AOE Toogle
  else
    EnemiesCount10ySplash = 1
  end

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
    -- use_items,slots=trinket1,if=trinket.1.has_use_buff&(buff.trueshot.up&(!trinket.2.has_use_buff|trinket.2.cooldown.remains|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)|buff.trueshot.down&(trinket.2.has_use_buff&trinket.2.cooldown.duration>=trinket.1.cooldown.duration&trinket.2.cooldown.remains-5<cooldown.trueshot.remains&cooldown.trueshot.remains>20|trinket.1.cooldown.duration-5<cooldown.trueshot.remains)|target.time_to_die<cooldown.trueshot.remains)|!trinket.1.has_use_buff&(trinket.2.has_use_buff&(buff.trueshot.down|trinket.2.cooldown.remains>5)&(cooldown.trueshot.remains>20|trinket.2.cooldown.remains-5>cooldown.trueshot.remains)|!trinket.2.has_use_buff&(!trinket.2.has_cooldown|trinket.2.cooldown.duration>=trinket.1.cooldown.duration|trinket.2.cooldown.remains))
    -- use_items,slots=trinket2,if=trinket.2.has_use_buff&(buff.trueshot.up&(!trinket.1.has_use_buff|trinket.1.cooldown.remains|trinket.2.cooldown.duration>=trinket.1.cooldown.duration)|buff.trueshot.down&(trinket.1.has_use_buff&trinket.1.cooldown.duration>=trinket.2.cooldown.duration&trinket.1.cooldown.remains-5<cooldown.trueshot.remains&cooldown.trueshot.remains>20|trinket.2.cooldown.duration-5<cooldown.trueshot.remains)|target.time_to_die<cooldown.trueshot.remains)|!trinket.2.has_use_buff&(trinket.1.has_use_buff&(buff.trueshot.down|trinket.1.cooldown.remains>5)&(cooldown.trueshot.remains>20|trinket.1.cooldown.remains-5>cooldown.trueshot.remains)|!trinket.1.has_use_buff&(!trinket.1.has_cooldown|trinket.1.cooldown.duration>=trinket.2.cooldown.duration|trinket.1.cooldown.remains))
    -- TODO: Handle these trinket lines, then delete the below use_items
    -- use_items,if=prev_gcd.1.trueshot|!talent.calling_the_shots.enabled|target.time_to_die<20
    if CDsON() and Settings.Commons.Enabled.Trinkets and (Player:PrevGCDP(1, S.Trueshot) or not S.CallingtheShots:IsAvailable() or Target:TimeToDie() < 20) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
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
  end
end

local function Init()
  HR.Print("MM APL is WIP")
end

HR.SetAPL(254, APL, Init)
