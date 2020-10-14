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

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

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

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  Marksmanship = HR.GUISettings.APL.Hunter.Marksmanship
};

-- Variables
local VarCAExecute = Target:HealthPercentage() > 70 and S.CarefulAim:IsAvailable()
local SoulForgeEmbersEquipped = (I.SoulForgeEmbersChest:IsEquipped() or I.SoulForgeEmbersHead:IsEquipped())

--Functions
local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function MasterMarksmanBuffCheck()
  return (Player:BuffUp(S.MasterMarksmanBuff) or (Player:IsCasting(S.AimedShot) and S.MasterMarksman:IsAvailable()))
end

-- target_if=min:remains,if=refreshable&target.time_to_die>duration
local function EvaluateTargetIfFilterSerpentRemains(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and TargetUnit:TimeToDie() > S.SerpentStingDebuff:BaseDuration()) 
end
local function EvaluateTargetIfSerpentSting(TargetUnit)
  return (TargetUnit:TimeToDie() > S.SerpentStingDebuff:BaseDuration())
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- tar_trap,if=runeforge.soulforge_embers.equipped
    if S.TarTrap:IsReady() and SoulForgeEmbersEquipped then
      if HR.Cast(S.TarTrap) then return "tar_trap soulforge_embers equipped"; end
    end
    -- double_tap,precast_time=10
    if S.DoubleTap:IsReady() then
      if HR.Cast(S.DoubleTap, Settings.Marksmanship.GCDasOffGCD.DoubleTap) then return "double_tap precast"; end
    end
    -- aimed_shot,if=active_enemies=1
    if S.AimedShot:IsReady() and EnemiesCount == 1 then
      if HR.Cast(S.AimedShot, nil, nil, not TargetIsInRange[40]) then return "aimed_shot opener"; end
    end
  end
end

local function Cds()
  -- berserking,if=prev_gcd.1.trueshot&(target.time_to_die>cooldown.berserking.duration+duration|(target.health.pct<20|!talent.careful_aim.enabled))|target.time_to_die<13
  if S.Berserking:IsReady() and (Player:PrevGCDP(1, S.Trueshot) and (Target:TimeToDie() > 180 + S.Berserking:BaseDuration() or (Target:HealthPercentage() < 20 or not S.CarefulAim:IsAvailable())) or Target:TimeToDie() < 13) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 86"; end
  end
  -- blood_fury,if=prev_gcd.1.trueshot&(target.time_to_die>cooldown.blood_fury.duration+duration|(target.health.pct<20|!talent.careful_aim.enabled))|target.time_to_die<16
  if S.BloodFury:IsReady() and (Player:PrevGCDP(1, S.Trueshot) and (Target:TimeToDie() > 120 + S.BloodFury:BaseDuration() or (Target:HealthPercentage() < 20 or not S.CarefulAim:IsAvailable())) or Target:TimeToDie() < 16) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 90"; end
  end
  -- ancestral_call,if=prev_gcd.1.trueshot&(target.time_to_die>cooldown.ancestral_call.duration+duration|(target.health.pct<20|!talent.careful_aim.enabled))|target.time_to_die<16
  if S.AncestralCall:IsReady() and (Player:PrevGCDP(1, S.Trueshot) and (Target:TimeToDie() > 120 + S.AncestralCall:BaseDuration() or (Target:HealthPercentage() < 20 or not S.CarefulAim:IsAvailable())) or Target:TimeToDie() < 16) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 94"; end
  end
  -- fireblood,if=prev_gcd.1.trueshot&(target.time_to_die>cooldown.fireblood.duration+duration|(target.health.pct<20|!talent.careful_aim.enabled))|target.time_to_die<9
  if S.Fireblood:IsReady() and (Player:PrevGCDP(1, S.Trueshot) and (Target:TimeToDie() > 120 + S.Fireblood:BaseDuration() or (Target:HealthPercentage() < 20 or not S.CarefulAim:IsAvailable())) or Target:TimeToDie() < 9) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 98"; end
  end
  -- lights_judgment,if=buff.trueshot.down
  if S.LightsJudgment:IsReady() and (not Player:BuffUp(S.Trueshot)) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "lights_judgment 102"; end
  end
  -- bag_of_tricks,if=buff.trueshot.down
  if S.BagofTricks:IsReady() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "bag_of_tricks"; end
  end
  -- potion wip
  if I.PotionOfSpectralAgility:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionOfSpectralAgility) then return "potion_of_spectral_agility"; end
  end
end

local function St()
  -- steady_shot,if=talent.steady_focus.enabled&prev_gcd.1.steady_shot&buff.steady_focus.remains<5
  if S.SteadyShot:IsReady() and (S.SteadyFocus:IsAvailable() and Player:PrevGCDP(1, S.SteadyShot) and Player:BuffRemains(S.SteadyFocusBuff) < 5) then
    if HR.Cast(S.SteadyShot, nil, nil, not TargetIsInRange[40]) then return "steady_shot st 1"; end
  end
  -- kill_shot
  if S.KillShot:IsReady() and Target:HealthPercentage() <= 20 then
    if HR.Cast(S.KillShot, nil, nil, not TargetIsInRange[40]) then return "kill_shot st 2"; end
  end
  -- double_tap
  if S.DoubleTap:IsReady() then
    if HR.Cast(S.DoubleTap, Settings.Marksmanship.GCDasOffGCD.DoubleTap) then return "double_tap st 3"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equipped&tar_trap.remains<gcd&cooldown.flare.remains<gcd
  if S.TarTrap:IsReady() and (SoulForgeEmbersEquipped and not S.TarTrap:CooldownRemains() < Player:GCD() and S.Flare:CooldownRemains() < Player:GCD()) then
    if HR.Cast(S.TarTrap, Settings.Commons.GCDasOffGCD.TarTrap) then return "tar_trap st 4"; end
  end
  -- flare,if=tar_trap.up
  if S.Flare:IsReady() and not S.TarTrap:CooldownUp() then
    if HR.Cast(S.Flare, Settings.Commons.GCDasOffGCD.Flare) then return "flare st 5"; end
  end
  -- wild_spirits
  if S.WildSpirits:IsReady() and HR.CDsON() then
    if HR.Cast(S.WildSpirits, nil, Settings.Commons.CovenantDisplayStyle) then return "wild_spirits fae st covenant "; end
  end
  -- flayed_shot
  if S.FlayedShot:IsReady() then
    if HR.Cast(S.FlayedShot, nil, Settings.Commons.CovenantDisplayStyle) then return "flayed_shot st venthyr covenant"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsReady() and (Player:Focus() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.DeathChakram, nil, Settings.Commons.CovenantDisplayStyle) then return "dark_chakram st necrolords covenant"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if HR.Cast(S.ExplosiveShot, nil, nil, not TargetIsInRange[40]) then return "explosive_shot 9"; end
  end
  -- volley,if=buff.precise_shots.down|!talent.chimaera_shot.enabled
  if S.Volley:IsReady() and (not Player:BuffUp(S.PreciseShotsBuff) or not S.ChimaeraShot:IsAvailable()) then
    if HR.Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetIsInRange[46])  then return "volley st 10 "; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if HR.Cast(S.AMurderofCrows, Settings.Marksmanship.GCDasOffGCD.AMurderofCrows, nil, not TargetIsInRange[40]) then return "a_murder_of_crows 136"; end
  end
  -- resonating_arrow
  if S.ResonatingArrow:IsReady() then
    if HR.Cast(S.ResonatingArrow, nil, Settings.Commons.CovenantDisplayStyle) then return "resonating_arrow st kyrian covenant"; end
  end
  -- trueshot,if=buff.precise_shots.down|!talent.chimaera_shot.enabled
  if S.Trueshot:IsReady() and (not Player:BuffUp(S.PreciseShotsBuff) or not S.ChimaeraShot:IsAvailable()) then
    if HR.Cast(S.Trueshot, Settings.Marksmanship.GCDasOffGCD.Trueshot) then return "trueshot st 13"; end
  end
  -- aimed_shot,if=(full_recharge_time<cast_time+gcd|buff.trueshot.up)&(buff.precise_shots.down|!talent.chimaera_shot.enabled|ca_active)|buff.trick_shots.remains>execute_time&(active_enemies>1|runeforge.serpentstalkers_trickery.equipped)
  if S.AimedShot:IsReady() and ((S.AimedShot:FullRechargeTime() < S.AimedShot:CastTime() + Player:GCD() or Player:BuffUp(S.Trueshot)) and (not Player:BuffUp(S.PreciseShotsBuff) or not S.ChimaeraShot:IsAvailable() or VarCAExecute) or Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:ExecuteTime() and (EnemiesCount > 1 or SerpentStalkersEquipped)) then
    if HR.Cast(S.AimedShot) then return "aimedshot_ st 14"; end
  end
  -- rapid_fire,if=buff.double_tap.down&focus+cast_regen<focus.max
  if S.RapidFire:IsReady() and (not Player:BuffUp(S.DoubleTap) and Player:Focus() + Player:FocusCastRegen(S.RapidFire:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.RapidFire, nil, nil, not TargetIsInRange[40]) then return "rapid_fire st 15"; end
  end
  -- chimaera_shot,if=buff.precise_shots.up&(buff.trueshot.down|active_enemies>1|!ca_active)
  if S.ChimaeraShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and (not Player:BuffUp(S.Trueshot) or EnemiesCount > 1 or not VarCAExecute)) then
    if HR.Cast(S.ChimaeraShot) then return "chimaera_shot st 16"; end
  end
  -- serpent_sting,target_if=min:remains,if=refreshable&target.time_to_die>duration
  if S.SerpentSting:IsReady() then
    if Everyone.CastCycle(S.SerpentSting, Enemies40yd, EvaluateTargetIfFilterSerpentRemains, not Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting st target_if"; end
  end
  -- barrage,if=active_enemies>1
  if S.Barrage:IsReady() and (EnemiesCount > 1) then
    if HR.Cast(S.Barrage, nil, nil, not TargetIsInRange[40]) then return "barrage st 18"; end
  end
  -- arcane_shot,if=buff.precise_shots.up&(buff.trueshot.down|!ca_active)
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and (not Player:BuffUp(S.Trueshot) or not VarCAExecute)) then
    if HR.Cast(S.ArcaneShot, nil, nil, not TargetIsInRange[40]) then return "arcane_shot st 19"; end
  end
  -- aimed_shot,if=buff.precise_shots.down
  if S.AimedShot:IsReady() and not Player:BuffUp(S.PreciseShotsBuff) then
    if HR.Cast(S.AimedShot, nil, nil, not TargetIsInRange[40]) then return "aimed_shot st 20"; end
  end
  -- chimaera_shot,if=focus>cost+action.aimed_shot.cost&(buff.trueshot.down|!ca_active)
  if S.ChimaeraShot:IsReady() and (Player:Focus() > S.ChimaeraShot:Cost() + S.AimedShot:Cost() and (not Player:BuffUp(S.Trueshot) or not VarCAExecute)) then
    if HR.Cast(S.ChimaeraShot) then return "chimaera_shot st 21"; end
  end
  -- arcane_shot,if=focus>cost+action.aimed_shot.cost&(buff.trueshot.down|!ca_active)
  if S.ArcaneShot:IsReady() and (Player:Focus() > S.ArcaneShot:Cost() + S.AimedShot:Cost() and (not Player:BuffUp(S.Trueshot) or not VarCAExecute)) then
    if HR.Cast(S.ArcaneShot) then return "arcane_shot st 21"; end
  end
  -- steady_shot,if=focus+cast_regen<focus.max
  if S.SteadyShot:IsReady() and (Player:Focus() + Player:FocusCastRegen(S.SteadyShot:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.SteadyShot, nil, nil, not TargetIsInRange[40]) then return "steady_shot st 22"; end
  end
  -- chimaera_shot
  if S.ChimaeraShot:IsReady() then
    if HR.Cast(S.ChimaeraShot) then return "chimaera_shot st 23"; end
  end
  -- arcane_shot
  if S.ArcaneShot:IsReady() then
    if HR.Cast(S.ChimaeraShot) then return "arcane_shot st 24"; end
  end
end

local function Trickshots()
  -- double_tap,if=cooldown.aimed_shot.up|cooldown.rapid_fire.remains>cooldown.aimed_shot.remains
  if S.DoubleTap:IsReady() and (S.AimedShot:CooldownUp() or S.RapidFire:CooldownRemains() > S.AimedShot:CooldownRemains()) then
    if HR.Cast(S.DoubleTap, Settings.Marksmanship.GCDasOffGCD.DoubleTap) then return "double_tap trickshots 1"; end
  end
  -- tar_trap,if=runeforge.soulforge_embers.equipped
  if S.TarTrap:IsReady() and SoulForgeEmbersEquipped then
    if HR.Cast(S.TarTrap) then return "tar_trap soulforge_embers equipped"; end
  end
  -- flare,if=tar_trap.up
  if S.Flare:IsReady() and not S.TarTrap:CooldownUp() then
    if HR.Cast(S.Flare, Settings.Commons.GCDasOffGCD.Flare) then return "flare trickshots 3 5"; end
  end
  -- wild_spirits
  if S.WildSpirits:IsReady() and HR.CDsON() then
    if HR.Cast(S.WildSpirits, nil, Settings.Commons.CovenantDisplayStyle) then return "wild_spirits fae trickshots covenant "; end
  end
  -- volley
  if S.Volley:IsReady() then
    if HR.Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley)  then return "volley trickshots 7 "; end
  end
  -- resonating_arrow
  if S.ResonatingArrow:IsReady() then
    if HR.Cast(S.ResonatingArrow, nil, Settings.Commons.CovenantDisplayStyle) then return "resonating_arrow trickshots kyrian covenant"; end
  end
  -- barrage
  if S.Barrage:IsReady() then
    if HR.Cast(S.Barrage, nil, nil, not TargetIsInRange[40]) then return "barrage trickshots 9"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if HR.Cast(S.ExplosiveShot, nil, nil, not TargetIsInRange[40]) then return "explosive_shot trickshots 10"; end
  end
  -- trueshot,if=cooldown.rapid_fire.remains|focus+action.rapid_fire.cast_regen>focus.max|target.time_to_die<15
  if S.Trueshot:IsReady() and (bool(S.RapidFire:CooldownRemains()) or Player:Focus() + Player:FocusCastRegen(S.RapidFire:ExecuteTime()) > Player:FocusMax() or Target:TimeToDie() < 15) then
    if HR.Cast(S.Trueshot, nil, nil, not TargetIsInRange[40]) then return "trueshot trickshots 11"; end
  end 
  -- aimed_shot,if=buff.trick_shots.up&(buff.precise_shots.down|full_recharge_time<cast_time+gcd|buff.trueshot.up)
  if S.AimedShot:IsReady() and (Player:BuffUp(S.TrickShotsBuff) and (not Player:BuffUp(S.PreciseShotsBuff) or S.AimedShot:FullRechargeTime() < S.AimedShot:CastTime() + Player:GCD() or Player:BuffUp(S.Trueshot))) then
    if HR.Cast(S.AimedShot, nil, nil, not TargetIsInRange[40]) then return "aimed_shot trickshots 12"; end
  end
  -- death_chakram,if=focus+cast_regen<focus.max
  if S.DeathChakram:IsReady() and (Player:Focus() + Player:FocusCastRegen(S.DeathChakram:ExecuteTime()) < Player:FocusMax()) then
    if HR.Cast(S.DeathChakram, nil, Settings.Commons.CovenantDisplayStyle) then return "dark_chakram trickshots necrolords covenant"; end
  end
  -- rapid_fire,if=buff.trick_shots.up&buff.double_tap.down
  if S.RapidFire:IsReady() and (Player:BuffUp(S.TrickShotsBuff) and not Player:BuffUp(S.DoubleTap)) then
    if HR.Cast(S.RapidFire, nil, nil, not TargetIsInRange[40]) then return "rapid_fire trickshots 14"; end
  end
  -- multishot,if=buff.trick_shots.down|buff.precise_shots.up|focus-cost+cast_regen>action.aimed_shot.cost
  if S.Multishot:IsReady() and (not Player:BuffUp(S.TrickShotsBuff) or Player:BuffUp(S.PreciseShotsBuff) or Player:Focus() - S.Multishot:Cost() + Player:FocusCastRegen(S.Multishot:ExecuteTime()) > S.AimedShot:Cost()) then
    if HR.Cast(S.Multishot, nil, nil, not TargetIsInRange[40]) then return "multishot trickshots 15"; end
  end
  -- kill_shot,if=buff.dead_eye.down
  if S.KillShot:IsReady() and not Player:BuffUp(S.DeadEyeBuff) and Target:HealthPercentage() <= 20 then
    if HR.Cast(S.KillShot, nil, nil, not TargetIsInRange[46]) then return "kill_shot trickshots 16"; end
  end
  -- a_murder_of_crows
  if S.AMurderofCrows:IsReady() then
    if HR.Cast(S.AMurderofCrows, Settings.Marksmanship.GCDasOffGCD.AMurderofCrows, nil, not TargetIsInRange[40]) then return "a_murder_of_crows 250"; end
  end
  -- flayed_shot
  if S.FlayedShot:IsReady() then
    if HR.Cast(S.FlayedShot, nil, Settings.Commons.CovenantDisplayStyle) then return "flayed_shot st venthyr covenant"; end
  end
  -- serpent_sting,target_if=min:dot.serpent_sting.remains,if=refreshable
  if S.SerpentSting:IsReady()  then
    if Everyone.CastCycle(S.SerpentSting, Enemies40yd, EvaluateTargetIfFilterSerpentRemains, Target:IsSpellInRange(S.SerpentSting)) then return "serpent_sting trickshots target_if"; end
  end
  -- steady_shot
  if S.SteadyShot:IsReady() then
    if HR.Cast(S.SteadyShot, nil, nil, not TargetIsInRange[40]) then return "steady_shot 266"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesCount = Target:GetEnemiesInSplashRangeCount(10) -- AOE Toogle
  Enemies40yd = Player:GetEnemiesInRange(40)
  ComputeTargetRange()

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Self heal, if below setting value
    if S.Exhilaration:IsReady() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
      if HR.Cast(S.Exhilaration, Settings.Commons.GCDasOffGCD.Exhilaration) then return "exhilaration"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(40, S.CounterShot, Settings.Commons.OffGCDasOffGCD.CounterShot, false); if ShouldReturn then return ShouldReturn; end
    -- auto_shot
    -- use_items,if=prev_gcd.1.trueshot|!talent.calling_the_shots.enabled|target.time_to_die<20
    if (Player:PrevGCDP(1, S.Trueshot) or not S.CallingtheShots:IsAvailable() or Target:TimeToDie() < 20) then
      local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- call_action_list,name=cds
    if (HR.CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3
    if (EnemiesCount < 3) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trickshots,if=active_enemies>2
    if (EnemiesCount > 2) then
      local ShouldReturn = Trickshots(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()
  HR.Print("MM APL is WIP")
end

HR.SetAPL(254, APL, Init)