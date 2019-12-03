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
if not Spell.Druid then Spell.Druid = {} end
Spell.Druid.Restoration = {
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BalanceAffinity                       = Spell(197632),
  FeralAffinity                         = Spell(197490),
  CatForm                               = Spell(768),
  CatFormBuff                           = Spell(768),
  MoonkinForm                           = Spell(197625),
  MoonkinFormBuff                       = Spell(197625),
  Prowl                                 = Spell(5215),
  Sunfire                               = Spell(93402),
  SunfireDebuff                         = Spell(164815),
  Moonfire                              = Spell(8921),
  MoonfireDebuff                        = Spell(164812),
  Starsurge                             = Spell(197626),
  LunarEmpowerment                      = Spell(164547),
  LunarStrike                           = Spell(197628),
  SolarWrath                            = Spell(5176),
  Rake                                  = Spell(1822),
  RakeDebuff                            = Spell(155722),
  Rip                                   = Spell(1079),
  RipDebuff                             = Spell(1079),
  FerociousBite                         = Spell(22568),
  SwipeCat                              = Spell(213764),
  Shred                                 = Spell(5221),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  ConcentratedFlameBurn                 = Spell(295368),
  Pool                                  = Spell(9999000010)
};
local S = Spell.Druid.Restoration;

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Restoration = {
  PotionofUnbridledFury            = Item(169299),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
};
local I = Item.Druid.Restoration;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount, EnemiesCountLR;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Restoration = HR.GUISettings.APL.Druid.Restoration
};

local EnemyRanges = {40, 8}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

HL:RegisterForEvent(function()
  S.ConcentratedFlame:RegisterInFlight();
end, "LEARNED_SPELL_IN_TAB")
S.ConcentratedFlame:RegisterInFlight();

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function GetEnemiesCount(range)
  -- Unit Update - Update differently depending on if splash data is being used
  if HR.AoEON() then
    if Settings.Restoration.UseSplashData then
      HL.GetEnemies(range, nil, true, Target)
      return Cache.EnemiesCount[range]
    else
      UpdateRanges()
      Everyone.AoEToggleEnemiesUpdate()
      return Cache.EnemiesCount[40]
    end
  else
    return 1
  end
end

local function EvaluateCycleSunfire301(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.SunfireDebuff)
end

local function EvaluateCycleMoonfire303(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.MoonfireDebuff) and EnemiesCountLR < 7
end

local function EvaluateCycleMoonfire305(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 12 and (EnemiesCount <= 4 or Player:Energy() < 50) and (Player:BuffDownP(S.MemoryofLucidDreams) or (TargetUnit:DebuffDownP(S.MoonfireDebuff) and EnemiesCount < 3)) or (Player:PrevGCDP(1, S.Sunfire) and TargetUnit:DebuffRemainsP(S.MoonfireDebuff) < S.MoonfireDebuff:BaseDuration() * 0.8 and EnemiesCountLR == 1)
end

local function EvaluateCycleRip307(TargetUnit)
  return (TargetUnit:DebuffRefreshableCP(S.RipDebuff) and (Player:ComboPoints() == 5 and TargetUnit:TimeToDie() > TargetUnit:DebuffRemainsP(S.RipDebuff) + 24 or (TargetUnit:DebuffRemainsP(S.RipDebuff) + Player:ComboPoints() * 4 < TargetUnit:TimeToDie() and TargetUnit:DebuffRemainsP(S.RipDebuff) + 4 + Player:ComboPoints() * 4 > TargetUnit:TimeToDie()))) or Player:ComboPoints() == 5 and Player:Energy() > 90 and TargetUnit:DebuffRemainsP(S.RipDebuff) <= 10
end

local function EvaluateCycleRake309(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.RakeDebuff) and TargetUnit:TimeToDie() > 10 and (Player:ComboPoints() < 5 or TargetUnit:DebuffRefreshableCP(S.RakeDebuff) < 1) and EnemiesCount < 4
end

local function EvaluateCycleMoonfire311(TargetUnit)
  return TargetUnit:DebuffRefreshableCP(S.MoonfireDebuff)
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Balance, Feral
  EnemiesCount = GetEnemiesCount(8)
  EnemiesCountLR = GetEnemiesCount(40)
  HL.GetEnemies(8)  -- For CastCycle Calls
  HL.GetEnemies(40) -- For CastCycle Calls
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    -- Manual opener tweak: Only do cat stuff with Feral Affinity
    if S.FeralAffinity:IsAvailable() then
      -- cat_form
      if S.CatForm:IsCastableP() and (Player:BuffDownP(S.CatFormBuff)) then
        if HR.Cast(S.CatForm) then return "cat_form 1"; end
      end
      -- prowl
      if S.Prowl:IsCastableP() and (Player:BuffP(S.CatFormBuff)) then
        if HR.Cast(S.Prowl, Settings.Restoration.GCDasOffGCD.Prowl) then return "prowl 3"; end
      end
      -- potion
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 5"; end
      end
      -- Manually add Rake opener
      if S.Rake:IsReadyP() and (Player:IsStealthed(true, false)) then
        if HR.Cast(S.Rake) then return "rake 7"; end
      end
    else
      -- potion
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 9"; end
      end
      -- Manually add Solar Wrath for non-cat
      if S.SolarWrath:IsCastableP() then
        if HR.Cast(S.SolarWrath) then return "solar_wrath 11"; end
      end
    end
  end
  Balance = function()
    -- sunfire,target_if=refreshable
    if S.Sunfire:IsReadyP() then
      if HR.CastCycle(S.Sunfire, 40, EvaluateCycleSunfire301) then return "sunfire 101" end
    end
    -- moonfire,target_if=refreshable&spell_targets.lunar_strike<7
    if S.Moonfire:IsReadyP() then
      if HR.CastCycle(S.Moonfire, 40, EvaluateCycleMoonfire303) then return "moonfire 103"; end
    end
    -- Manually add Moonkin Form, as it's needed for Starsurge and Lunar Strike
    if S.MoonkinForm:IsCastableP() and (Player:BuffDownP(S.MoonkinFormBuff)) then
      if HR.Cast(S.MoonkinForm) then return "moonkin_form 105"; end
    end
    -- starsurge
    if S.Starsurge:IsReadyP() then
      if HR.Cast(S.Starsurge) then return "starsurge 107"; end
    end
    -- lunar_strike,if=buff.lunar_empowerment.up|spell_targets>1
    if S.LunarStrike:IsReadyP() and (Player:BuffP(S.LunarEmpowerment) or EnemiesCountLR > 1) then
      if HR.Cast(S.LunarStrike) then return "lunar_strike 109"; end
    end
    -- solar_wrath
    if S.SolarWrath:IsCastableP() then
      if HR.Cast(S.SolarWrath) then return "solar_wrath 111"; end
    end
  end
  Feral = function()
    -- rake,if=buff.shadowmeld.up|buff.prowl.up
    -- Manually added DebuffDownP requirement to avoid double Rake opener
    if S.Rake:IsReadyP() and (not Player:IsStealthed(true, true) and Target:DebuffDownP(S.RakeDebuff)) then
      if HR.Cast(S.Rake) then return "rake 201"; end
    end
    -- auto_attack
    -- sunfire,target_if=refreshable
    if S.Sunfire:IsReadyP() then
      if HR.CastCycle(S.Sunfire, 40, EvaluateCycleSunfire301) then return "sunfire 203"; end
    end
    -- moonfire,target_if=refreshable&time_to_die>12&(spell_targets.swipe_cat<=4|energy<50)&(!buff.memory_of_lucid_dreams.up|(!ticking&spell_targets.swipe_cat<3))|(prev_gcd.1.sunfire&remains<duration*0.8&spell_targets.sunfire=1)
    if S.Moonfire:IsReadyP() then
      if HR.CastCycle(S.Moonfire, 40, EvaluateCycleMoonfire305) then return "moonfire 205"; end
    end
    -- sunfire,if=prev_gcd.1.moonfire&remains<duration*0.8
    if S.Sunfire:IsReadyP() and (Player:PrevGCDP(1, S.Moonfire) and Target:DebuffRemainsP(S.SunfireDebuff) < S.SunfireDebuff:BaseDuration() * 0.8) then
      if HR.Cast(S.Sunfire) then return "sunfire 207"; end
    end
    -- cat_form,if=!buff.cat_form.up&energy>50
    if S.CatForm:IsCastableP() and (Player:BuffDownP(S.CatFormBuff) and Player:Energy() > 50) then
      if HR.Cast(S.CatForm) then return "cat_form 209"; end
    end
    -- solar_wrath,if=!buff.cat_form.up
    if S.SolarWrath:IsCastableP() and (Player:BuffDownP(S.CatFormBuff)) then
      if HR.Cast(S.SolarWrath) then return "solar_wrath 211"; end
    end
    -- ferocious_bite,if=(combo_points>3&target.1.time_to_die<3)|(combo_points=5&energy>=50&dot.rip.remains>10)&spell_targets.swipe_cat<5
    if S.FerociousBite:IsReadyP() and ((Player:ComboPoints() > 3 and Target:TimeToDie() < 3) or (Player:ComboPoints() == 5 and Player:Energy() >= 50 and Target:DebuffRemainsP(S.RipDebuff) > 10) and EnemiesCount < 5) then
      if HR.Cast(S.FerociousBite) then return "ferocious_bite 213"; end
    end
    -- rip,target_if=(refreshable&(combo_points=5&time_to_die>remains+24|(remains+combo_points*4<time_to_die&remains+4+combo_points*4>time_to_die)))|combo_points=5&energy>90&remains<=10
    if S.Rip:IsReadyP() then
      if HR.CastCycle(S.Rip, 8, EvaluateCycleRip307) then return "rip 215"; end
    end
    -- rake,target_if=refreshable&time_to_die>10&(combo_points<5|remains<1)&spell_targets.swipe_cat<4
    if S.Rake:IsReadyP() then
      if HR.CastCycle(S.Rake, 8, EvaluateCycleRake309) then return "rake 217"; end
    end
    -- swipe_cat,if=spell_targets.swipe_cat>=2
    if S.SwipeCat:IsReadyP() and (EnemiesCount >= 2) then
      if HR.Cast(S.SwipeCat) then return "swipe_cat 219"; end
    end
    -- shred,if=combo_points<5|energy>90
    if S.Shred:IsReadyP() and (Player:ComboPoints() < 5 or Player:Energy() > 90) then
      if HR.Cast(S.Shred) then return "shred 221"; end
    end
    -- Give Pool icon if waiting on energy
    if (true) then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Energy"; end
    end
  end
  -- Call Precombat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    if HR.CDsON() then
      -- blood_fury
      if S.BloodFury:IsCastableP() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 31"; end
      end
      -- berserking
      if S.Berserking:IsCastableP() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 33"; end
      end
      -- arcane_torrent
      if S.ArcaneTorrent:IsCastableP() then
        if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 35"; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastableP() then
        if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment 37"; end
      end
      -- fireblood
      if S.Fireblood:IsCastableP() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 39"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastableP() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 41"; end
      end
    end
    -- use_item,effect_name=cyclotronic_blast,if=!buff.prowl.up&!buff.shadowmeld.up
    if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (not Player:IsStealthed(true, true)) then
      if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "cyclotronic_blast 43"; end
    end
    -- use_items
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion_of_unbridled_fury 45"; end
    end
    -- memory_of_lucid_dreams,if=buff.cat_form.up&energy<50&dot.sunfire.remains>5&dot.moonfire.remains>5
    if S.MemoryofLucidDreams:IsCastableP() and (Player:BuffP(S.CatFormBuff) and Player:Energy() < 50 and Target:DebuffRemainsP(S.SunfireDebuff) > 5 and Target:DebuffRemainsP(S.MoonfireDebuff) > 5) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 47"; end
    end
    -- concentrated_flame,if=!dot.concentrated_flame_burn.remains&!action.concentrated_flame.in_flight&!buff.shadowmeld.up&!buff.prowl.up
    if S.ConcentratedFlame:IsCastableP() and (Target:DebuffDownP(S.ConcentratedFlameBurn) and not S.ConcentratedFlame:InFlight() and not Player:IsStealthed(true, true)) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame 49"; end
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
    if S.Sunfire:IsReadyP() then
      if HR.CastCycle(S.Sunfire, 40, EvaluateCycleSunfire301) then return "sunfire 51"; end
    end
    -- moonfire,target_if=refreshable
    if S.Moonfire:IsReadyP() then
      if HR.CastCycle(S.Moonfire, 40, EvaluateCycleMoonfire311) then return "moonfire 53"; end
    end
    -- solar_wrath
    -- Manually add Cat Form check to ensure it's not asking to come out of cat for only a split second
    if S.SolarWrath:IsCastableP() and (Player:BuffDownP(S.CatFormBuff)) then
      if HR.Cast(S.SolarWrath) then return "solar_wrath 55"; end
    end
  end
end

local function Init ()
  HL.RegisterNucleusAbility(164815, 8, 6)               -- Sunfire DoT
  HL.RegisterNucleusAbility(194153, 8, 6)               -- Lunar Strike
end

HR.SetAPL(105, APL, Init)