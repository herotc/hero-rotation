--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
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

-- Spells

local S = Spell.Druid.Restoration;
local I = Item.Druid.Restoration;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount, EnemiesCountLR, EnemiesLR;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Restoration = HR.GUISettings.APL.Druid.Restoration
};

local function EvaluateCycleSunfire301(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.SunfireDebuff)
end

local function EvaluateCycleMoonfire303(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and EnemiesCountLR < 7
end

local function EvaluateCycleMoonfire305(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 12 and (EnemiesCount <= 4 or Player:Energy() < 50) and (Player:BuffDown(S.MemoryofLucidDreams) or (TargetUnit:DebuffDown(S.MoonfireDebuff) and EnemiesCount < 3)) or (Player:PrevGCDP(1, S.Sunfire) and TargetUnit:DebuffRemains(S.MoonfireDebuff) < S.MoonfireDebuff:BaseDuration() * 0.8 and EnemiesCountLR == 1)
end

local function EvaluateCycleRip307(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.RipDebuff) and (Player:ComboPoints() == 5 and TargetUnit:TimeToDie() > TargetUnit:DebuffRemains(S.RipDebuff) + 24 or (TargetUnit:DebuffRemains(S.RipDebuff) + Player:ComboPoints() * 4 < TargetUnit:TimeToDie() and TargetUnit:DebuffRemains(S.RipDebuff) + 4 + Player:ComboPoints() * 4 > TargetUnit:TimeToDie()))) or Player:ComboPoints() == 5 and Player:Energy() > 90 and TargetUnit:DebuffRemains(S.RipDebuff) <= 10
end

local function EvaluateCycleRake309(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.RakeDebuff) and TargetUnit:TimeToDie() > 10 and (Player:ComboPoints() < 5 or TargetUnit:DebuffRemains(S.RakeDebuff) < 1) and EnemiesCount < 4
end

local function EvaluateCycleMoonfire311(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.MoonfireDebuff)
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manual opener tweak: Only do cat stuff with Feral Affinity
  if S.FeralAffinity:IsAvailable() then
    -- cat_form
    if S.CatForm:IsCastable() and (Player:BuffDown(S.CatFormBuff)) then
      if HR.Cast(S.CatForm) then return "cat_form 1"; end
    end
    -- prowl
    if S.Prowl:IsCastable() and (Player:BuffUp(S.CatFormBuff)) then
      if HR.Cast(S.Prowl, Settings.Restoration.GCDasOffGCD.Prowl) then return "prowl 3"; end
    end
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 5"; end
    end
    -- Manually add Rake opener
    if S.Rake:IsReady() and (Player:StealthUp(true, false)) then
      if HR.Cast(S.Rake, nil, nil, "Melee") then return "rake 7"; end
    end
  else
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 9"; end
    end
    -- Manually add Solar Wrath for non-cat
    if S.SolarWrath:IsCastable() then
      if HR.Cast(S.SolarWrath, nil, nil, 40) then return "solar_wrath 11"; end
    end
  end
end

local function Balance()
  -- sunfire,target_if=refreshable
  if S.Sunfire:IsReady() then
    if Everyone.CastCycle(S.Sunfire, 40, EvaluateCycleSunfire301) then return "sunfire 101" end
  end
  -- moonfire,target_if=refreshable&spell_targets.lunar_strike<7
  if S.Moonfire:IsReady() then
    if Everyone.CastCycle(S.Moonfire, 40, EvaluateCycleMoonfire303) then return "moonfire 103"; end
  end
  -- Manually add Moonkin Form, as it's needed for Starsurge and Lunar Strike
  if S.MoonkinForm:IsCastable() and (Player:BuffDown(S.MoonkinFormBuff)) then
    if HR.Cast(S.MoonkinForm) then return "moonkin_form 105"; end
  end
  -- starsurge
  if S.Starsurge:IsReady() then
    if HR.Cast(S.Starsurge, nil, nil, 40) then return "starsurge 107"; end
  end
  -- lunar_strike,if=buff.lunar_empowerment.up|spell_targets>1
  if S.LunarStrike:IsReady() and (Player:BuffUp(S.LunarEmpowerment) or EnemiesCountLR > 1) then
    if HR.Cast(S.LunarStrike, nil, nil, 40) then return "lunar_strike 109"; end
  end
  -- solar_wrath
  if S.SolarWrath:IsCastable() then
    if HR.Cast(S.SolarWrath, nil, nil, 40) then return "solar_wrath 111"; end
  end
end

local function Feral()
  -- rake,if=buff.shadowmeld.up|buff.prowl.up
  -- Manually added DebuffDownP requirement to avoid double Rake opener
  if S.Rake:IsReady() and (not Player:StealthUp(true, true) and Target:DebuffDown(S.RakeDebuff)) then
    if HR.Cast(S.Rake, nil, nil, "Melee") then return "rake 201"; end
  end
  -- auto_attack
  -- sunfire,target_if=refreshable
  if S.Sunfire:IsReady() then
    if Everyone.CastCycle(S.Sunfire, 40, EvaluateCycleSunfire301) then return "sunfire 203"; end
  end
  -- moonfire,target_if=refreshable&time_to_die>12&(spell_targets.swipe_cat<=4|energy<50)&(!buff.memory_of_lucid_dreams.up|(!ticking&spell_targets.swipe_cat<3))|(prev_gcd.1.sunfire&remains<duration*0.8&spell_targets.sunfire=1)
  if S.Moonfire:IsReady() then
    if Everyone.CastCycle(S.Moonfire, 40, EvaluateCycleMoonfire305) then return "moonfire 205"; end
  end
  -- sunfire,if=prev_gcd.1.moonfire&remains<duration*0.8
  if S.Sunfire:IsReady() and (Player:PrevGCDP(1, S.Moonfire) and Target:DebuffRemains(S.SunfireDebuff) < S.SunfireDebuff:BaseDuration() * 0.8) then
    if HR.Cast(S.Sunfire, nil, nil, 40) then return "sunfire 207"; end
  end
  -- cat_form,if=!buff.cat_form.up&energy>50
  if S.CatForm:IsCastable() and (Player:BuffDown(S.CatFormBuff) and Player:Energy() > 50) then
    if HR.Cast(S.CatForm) then return "cat_form 209"; end
  end
  -- solar_wrath,if=!buff.cat_form.up
  if S.SolarWrath:IsCastable() and (Player:BuffDown(S.CatFormBuff)) then
    if HR.Cast(S.SolarWrath, nil, nil, 40) then return "solar_wrath 211"; end
  end
  -- ferocious_bite,if=(combo_points>3&target.1.time_to_die<3)|(combo_points=5&energy>=50&dot.rip.remains>10)&spell_targets.swipe_cat<5
  if S.FerociousBite:IsReady() and ((Player:ComboPoints() > 3 and Target:TimeToDie() < 3) or (Player:ComboPoints() == 5 and Player:Energy() >= 50 and Target:DebuffRemains(S.RipDebuff) > 10) and EnemiesCount < 5) then
    if HR.Cast(S.FerociousBite, nil, nil, "Melee") then return "ferocious_bite 213"; end
  end
  -- rip,target_if=(refreshable&(combo_points=5&time_to_die>remains+24|(remains+combo_points*4<time_to_die&remains+4+combo_points*4>time_to_die)))|combo_points=5&energy>90&remains<=10
  if S.Rip:IsReady() then
    if Everyone.CastCycle(S.Rip, 8, EvaluateCycleRip307) then return "rip 215"; end
  end
  -- rake,target_if=refreshable&time_to_die>10&(combo_points<5|remains<1)&spell_targets.swipe_cat<4
  if S.Rake:IsReady() then
    if Everyone.CastCycle(S.Rake, 8, EvaluateCycleRake309) then return "rake 217"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>=2
  if S.SwipeCat:IsReady() and (EnemiesCount >= 2) then
    if HR.Cast(S.SwipeCat, nil, nil, 8) then return "swipe_cat 219"; end
  end
  -- shred,if=combo_points<5|energy>90
  if S.Shred:IsReady() and (Player:ComboPoints() < 5 or Player:Energy() > 90) then
    if HR.Cast(S.Shred, nil, nil, "Melee") then return "shred 221"; end
  end
  -- Give Pool icon if waiting on energy
  if (true) then
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Energy"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesLR = Player:GetEnemiesInRange(40)
  EnemiesCount = #Player:GetEnemiesInRange(8)
  EnemiesCountLR = #EnemiesLR  
	
  -- Call Precombat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    if HR.CDsON() then
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 31"; end
      end
      -- berserking
      if S.Berserking:IsCastable() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 33"; end
      end
      -- arcane_torrent
      if S.ArcaneTorrent:IsCastable() then
        if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent 35"; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastable() then
        if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 37"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 39"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 41"; end
      end
      -- bag_of_tricks
      if S.BagofTricks:IsCastable() then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 42"; end
      end
    end
    -- use_items
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
    -- worldvein_resonance,if=!buff.shadowmeld.up&!buff.prowl.up&dot.sunfire.remains>6&(buff.cat_form.up|!talent.feral_affinity.enabled)
    if S.WorldveinResonance:IsCastable() and (not Player:BuffUp(S.Shadowmeld) and not Player:BuffUp(S.Prowl) and Target:DebuffRemains(S.SunfireDebuff) > 6 and (Player:BuffUp(S.CatFormBuff) or not S.FeralAffinity:IsAvailable())) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 44"; end
    end
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 45"; end
    end
    -- memory_of_lucid_dreams,if=buff.cat_form.up&energy<50&dot.sunfire.remains>5&dot.moonfire.remains>5
    if S.MemoryofLucidDreams:IsCastable() and (Player:BuffUp(S.CatFormBuff) and Player:Energy() < 50 and Target:DebuffRemains(S.SunfireDebuff) > 5 and Target:DebuffRemains(S.MoonfireDebuff) > 5) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 47"; end
    end
    -- run_action_list,name=feral,if=talent.feral_affinity.enabled
    if (S.FeralAffinity:IsAvailable()) then
      local ShouldReturn = Feral(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=balance,if=talent.balance_affinity.enabled
    if (S.BalanceAffinity:IsAvailable()) then
      local ShouldReturn = Balance(); if ShouldReturn then return ShouldReturn; end
    end
    -- sunfire,target_if=refreshable
    if S.Sunfire:IsReady() then
      if Everyone.CastCycle(S.Sunfire, EnemiesLR, EvaluateCycleSunfire301) then return "sunfire 51"; end
    end
    -- moonfire,target_if=refreshable
    if S.Moonfire:IsReady() then
      if Everyone.CastCycle(S.Moonfire, EnemiesLR, EvaluateCycleMoonfire311) then return "moonfire 53"; end
    end
    -- solar_wrath
    -- Manually add Cat Form check to ensure it's not asking to come out of cat for only a split second
    if S.SolarWrath:IsCastable() and (Player:BuffDown(S.CatFormBuff)) then
      if HR.Cast(S.SolarWrath, nil, nil, 40) then return "solar_wrath 55"; end
    end
  end
end

local function Init()
--  HL.RegisterNucleusAbility(164815, 8, 6)               -- Sunfire DoT
--  HL.RegisterNucleusAbility(194153, 8, 6)               -- Lunar Strike
end

HR.SetAPL(105, APL, Init)