--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Pet           = Unit.Pet
local Target        = Unit.Target
local Spell         = HL.Spell
local MultiSpell    = HL.MultiSpell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Restoration = HR.GUISettings.APL.Druid.Restoration
}

-- Spells
local S = Spell.Druid.Restoration

-- Items
local I = Item.Druid.Restoration
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Enemies Variables
local Enemies8ySplash, EnemiesCount8ySplash
local BossFightRemains = 11111
local FightRemains = 11111

-- Eclipse Variables
local EclipseInAny = false
local EclipseInBoth = false
local EclipseInLunar = false
local EclipseInSolar = false
local EclipseLunarNext = false
local EclipseSolarNext = false
local EclipseAnyNext = false

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

-- PMultiplier Registration
local function ComputeRakePMultiplier()
  return Player:StealthUp(true, true) and 1.6 or 1
end
S.Rake:RegisterPMultiplier(S.RakeDebuff, ComputeRakePMultiplier)

-- Helper Functions
local function EclipseCheck()
  EclipseInAny = (Player:BuffUp(S.EclipseSolar) or Player:BuffUp(S.EclipseLunar))
  EclipseInBoth = (Player:BuffUp(S.EclipseSolar) and Player:BuffUp(S.EclipseLunar))
  EclipseInLunar = (Player:BuffUp(S.EclipseLunar) and Player:BuffDown(S.EclipseSolar))
  EclipseInSolar = (Player:BuffUp(S.EclipseSolar) and Player:BuffDown(S.EclipseLunar))
  EclipseLunarNext = (not EclipseInAny and (S.Starfire:Count() == 0 and S.Wrath:Count() > 0 or Player:IsCasting(S.Wrath))) or EclipseInSolar
  EclipseSolarNext = (not EclipseInAny and (S.Wrath:Count() == 0 and S.Starfire:Count() > 0 or Player:IsCasting(S.Starfire))) or EclipseInLunar
  EclipseAnyNext = (not EclipseInAny and S.Wrath:Count() > 0 and S.Starfire:Count() > 0)
end

local function EvaluateTargetIfFilterAdaptiveSwarm(TargetUnit)
  return (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff))
end

local function EvaluateTargetIfAdaptiveSwarm(TargetUnit)
  return (TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) > 2)
end

local function EvaluateCycleAdaptiveSwarmCount1(TargetUnit)
  return (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) == 1 and TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) > 2)
end

local function EvaluateCycleAdaptiveSwarmCount2(TargetUnit)
  return (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) == 2 and TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) > 2)
end

local function EvaluateCycleAdaptiveSwarmCount3(TargetUnit)
  return (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) == 3 and TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) > 2)
end

local function EvaluateCycleAdaptiveSwarmCount4(TargetUnit)
  return (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) == 4 and TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) > 2)
end

local function EvaluateCycleAdaptiveSwarmDown(TargetUnit)
  return TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) == 0
end

local function EvaluateCycleCatSunfire(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SunfireDebuff) and FightRemains > 5)
end

local function EvaluateCycleCatMoonfire(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and FightRemains > 12 and (((EnemiesCount8ySplash <= 4 + 4 * num(CovenantID == 4) or Player:Energy() < 50) and Player:BuffDown(S.HeartoftheWildBuff)) or ((EnemiesCount8ySplash <= 4 or Player:Energy() < 50) and Player:BuffUp(S.HeartoftheWildBuff))) and TargetUnit:DebuffDown(S.MoonfireDebuff) or (Player:PrevGCD(1, S.Sunfire) and (TargetUnit:DebuffUp(S.MoonfireDebuff) and TargetUnit:DebuffRemains(S.MoonfireDebuff) < TargetUnit:DebuffDuration(S.MoonfireDebuff) * 0.8 or TargetUnit:DebuffDown(S.MoonfireDebuff)) and EnemiesCount8ySplash == 1))
end

local function EvaluateCycleCatRip(TargetUnit)
  return ((TargetUnit:DebuffRefreshable(S.RipDebuff) or Player:Energy() > 90 and TargetUnit:DebuffRemains(S.RipDebuff) <= 10) and (Player:ComboPoints() == 5 and TargetUnit:TimeToDie() > TargetUnit:DebuffRemains(S.RipDebuff) + 24 or (TargetUnit:DebuffRemains(S.RipDebuff) + Player:ComboPoints() * 4 < TargetUnit:TimeToDie() and TargetUnit:DebuffRemains(S.RipDebuff) + 4 + Player:ComboPoints() * 4 > TargetUnit:TimeToDie())) or TargetUnit:DebuffDown(S.RipDebuff) and Player:ComboPoints() > 2 + EnemiesCount8ySplash * 2)
end

local function EvaluateCycleCatRake(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.RakeDebuff) and TargetUnit:TimeToDie() > 10 and (Player:ComboPoints() < 5 or TargetUnit:DebuffRemains(S.RakeDebuff)))
end

local function EvaluateCycleCatRake2(TargetUnit)
  return (TargetUnit:DebuffUp(S.AdaptiveSwarmDebuff))
end

local function EvaluateCycleOwlDoT(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 5)
end

-- APL Functions
local function Precombat()
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and (Player:BuffDown(S.MarkoftheWildBuff, true) or Everyone.GroupBuffMissing(S.MarkoftheWildBuff)) then
    if Cast(S.MarkoftheWild, Settings.Commons.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat"; end
  end
  if S.FeralAffinity:IsAvailable() then
    -- cat_form,if=talent.feral_affinity.enabled
    if S.CatForm:IsReady() then
      if Cast(S.CatForm) then return "cat_form precombat 2"; end
    end
    -- prowl,if=talent.feral_affinity.enabled
    if S.Prowl:IsReady() then
      if Cast(S.Prowl) then return "prowl precombat 4"; end
    end
  end
  -- moonkin_form,if=talent.balance_affinity.enabled
  if S.MoonkinForm:IsReady() and (S.BalanceAffinity:IsAvailable()) then
    if Cast(S.MoonkinForm) then return "moonkin_form precombat 6"; end
  end
  -- Manually added: shred,if=talent.feral_affinity.enabled
  if S.Shred:IsReady() and (S.FeralAffinity:IsAvailable()) then
    if Cast(S.Shred, nil, nil, not Target:IsSpellInRange(S.Shred)) then return "shred precombat 8"; end
  end
  if not S.FeralAffinity:IsAvailable() then
    -- Manually added: moonfire,if=!talent.feral_affinity.enabled
    if S.Moonfire:IsReady() then
      if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire precombat 10"; end
    end
    -- Manually added: sunfire,if=!talent.feral_affinity.enabled
    if S.Sunfire:IsReady() then
      if Cast(S.Sunfire, nil, nil, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire precombat 12"; end
    end
  end
end

local function Cat()
  -- rake,if=buff.shadowmeld.up|buff.prowl.up
  if S.Rake:IsReady() and (Player:StealthUp(false, true)) then
    if Cast(S.Rake, nil, nil, not Target:IsInMeleeRange(10)) then return "rake cat 2"; end
  end
  -- use_items,if=!buff.prowl.up&!buff.shadowmeld.up
  if (not Player:StealthUp(false, true)) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- auto_attack,if=!buff.prowl.up&!buff.shadowmeld.up
  -- Note: Not handled...
  if CovenantID == 4 then
    -- adaptive_swarm,target_if=dot.adaptive_swarm_damage.stack=2&dot.adaptive_swarm_damage.remains>2
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmCount2, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm cat 4"; end
      end
      -- adaptive_swarm,target_if=dot.adaptive_swarm_damage.stack=1&dot.adaptive_swarm_damage.remains>2
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmCount1, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm cat 6"; end
      end
      -- adaptive_swarm,target_if=dot.adaptive_swarm_damage.stack=3&dot.adaptive_swarm_damage.remains>2
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmCount3, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm cat 8"; end
      end
      -- adaptive_swarm,target_if=dot.adaptive_swarm_damage.stack=4&dot.adaptive_swarm_damage.remains>2
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmCount4, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm cat 10"; end
      end
      -- adaptive_swarm,target_if=!dot.adaptive_swarm_damage.ticking
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmDown, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm cat 12"; end
      end
  end
  -- kindred_spirits
  if S.KindredSpirits:IsCastable() then
    if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Signature) then return "kindred_spirits cat 14"; end
  end
  -- ravenous_frenzy,if=(buff.heart_of_the_wild.up|cooldown.heart_of_the_wild.remains>60|!talent.heart_of_the_wild.enabled)
  if S.RavenousFrenzy:IsCastable() and CDsON() and (Player:BuffUp(S.HeartoftheWildBuff) or S.HeartoftheWild:CooldownRemains() > 60 or not S.HeartoftheWild:IsAvailable()) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Signature) then return "ravenous_frenzy cat 16"; end
  end
  -- convoke_the_spirits,if=(buff.heart_of_the_wild.up|cooldown.heart_of_the_wild.remains>60-30*runeforge.celestial_spirits|!talent.heart_of_the_wild.enabled)&buff.cat_form.up&energy<50&(combo_points<5&dot.rip.remains>5|spell_targets.swipe_cat>1)
  if S.ConvoketheSpirits:IsCastable() and CDsON() and ((Player:BuffUp(S.HeartoftheWildBuff) or S.HeartoftheWild:CooldownRemains() > 60 - 30 * num(CelestialSpiritsEquipped) or not S.HeartoftheWild:IsAvailable()) and Player:BuffUp(S.CatForm) and Player:Energy() < 50 and (Player:ComboPoints() < 5 and Target:DebuffRemains(S.RipDebuff) > 5 or EnemiesCount8ySplash > 1)) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "convoke_the_spirits cat 18"; end
  end
  -- sunfire,target_if=(refreshable&target.time_to_die>5)&!prev_gcd.1.cat_form
  if S.Sunfire:IsReady() and (not Player:PrevGCD(1, S.CatForm)) then
    if Everyone.CastCycle(S.Sunfire, Enemies8ySplash, EvaluateCycleCatSunfire, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire cat 20"; end
  end
  -- moonfire,target_if=(refreshable&time_to_die>12&(((spell_targets.swipe_cat<=4+4*covenant.necrolord|energy<50)&!buff.heart_of_the_wild.up)|((spell_targets.swipe_cat<=4|energy<50)&buff.heart_of_the_wild.up))&!ticking|(prev_gcd.1.sunfire&remains<duration*0.8&spell_targets.sunfire=1))&!prev_gcd.1.cat_form
  if S.Moonfire:IsReady() and (not Player:PrevGCD(1, S.CatForm)) then
    if Everyone.CastCycle(S.Moonfire, Enemies8ySplash, EvaluateCycleCatMoonfire, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire cat 22"; end
  end
  -- sunfire,if=prev_gcd.1.moonfire&remains<duration*0.8
  -- Manually added !prev_gcd.2.sunfire to stop the sunfire -> moonfire -> sunfire loop
  if S.Sunfire:IsReady() and ((not Player:PrevGCD(2, S.Sunfire)) and Player:PrevGCD(1, S.Moonfire) and (Target:DebuffUp(S.SunfireDebuff) and Target:DebuffRemains(S.SunfireDebuff) < Target:DebuffDuration(S.SunfireDebuff) * 0.8 or Target:DebuffDown(S.SunfireDebuff))) then
    if Cast(S.Sunfire, nil, nil, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire cat 24"; end
  end
  -- heart_of_the_wild,if=(cooldown.convoke_the_spirits.remains<30|!covenant.night_fae)&!buff.heart_of_the_wild.up&dot.sunfire.ticking&(dot.moonfire.ticking|spell_targets.swipe_cat>4+2*covenant.necrolord)
  if S.HeartoftheWild:IsCastable() and CDsON() and ((S.ConvoketheSpirits:CooldownRemains() < 30 or CovenantID ~= 3) and Player:BuffDown(S.HeartoftheWildBuff) and Target:DebuffUp(S.SunfireDebuff) and (Target:DebuffUp(S.MoonfireDebuff) or EnemiesCount8ySplash > 4 + 2 * num(CovenantID == 4))) then
    if Cast(S.HeartoftheWild, Settings.Restoration.GCDasOffGCD.HeartOfTheWild) then return "heart_of_the_wild cat 26"; end
  end
  -- cat_form,if=!buff.cat_form.up&energy>50
  if S.CatForm:IsReady() and (Player:BuffDown(S.CatForm) and Player:Energy() > 50) then
    if Cast(S.CatForm) then return "cat_form cat 28"; end
  end
  -- wrath,if=!buff.cat_form.up
  if S.Wrath:IsReady() and (Player:BuffDown(S.CatForm)) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath cat 30"; end
  end
  -- ferocious_bite,if=(combo_points>3&target.1.time_to_die<3|combo_points=5&energy>=50&dot.rip.remains>10)&spell_targets.swipe_cat<4
  if S.FerociousBite:IsReady() and ((Player:ComboPoints() > 3 and Target:TimeToDie() < 3 or Player:ComboPoints() == 5 and Player:Energy() >= 50 and Target:DebuffRemains(S.RipDebuff) > 10) and EnemiesCount8ySplash < 4) then
    if Cast(S.FerociousBite, nil, nil, not Target:IsInMeleeRange(5)) then return "ferocious_bite cat 32"; end
  end
  -- rip,target_if=((refreshable|energy>90&remains<=10)&(combo_points=5&time_to_die>remains+24|(remains+combo_points*4<time_to_die&remains+4+combo_points*4>time_to_die))|!ticking&combo_points>2+spell_targets.swipe_cat*2)&spell_targets.swipe_cat<11
  if S.Rip:IsReady() and (EnemiesCount8ySplash < 11) then
    if Everyone.CastCycle(S.Rip, Enemies8ySplash, EvaluateCycleCatRip, not Target:IsInMeleeRange(5)) then return "rip cat 34"; end
  end
  -- rake,target_if=refreshable&time_to_die>10&(combo_points<5|remains<1)&spell_targets.swipe_cat<5
  if S.Rake:IsReady() and (EnemiesCount8ySplash < 5) then
    if Everyone.CastCycle(S.Rake, Enemies8ySplash, EvaluateCycleCatRake, not Target:IsInMeleeRange(5)) then return "rake cat 36"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>=2
  if S.Swipe:IsReady() and (EnemiesCount8ySplash >= 2) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe cat 38"; end
  end
  -- rake,target_if=dot.adaptive_swarm_damage.ticking&runeforge.draught_of_deep_focus,if=(combo_points<5|energy>90)&runeforge.draught_of_deep_focus&dot.rake.pmultiplier<=persistent_multiplier
  if S.Rake:IsReady() and ((Player:ComboPoints() < 5 or Player:Energy() > 90) and DeepFocusEquipped and Target:PMultiplier(S.Rake) <= Player:PMultiplier(S.Rake)) then
    if Everyone.CastCycle(S.Rake, Enemies8ySplash, EvaluateCycleCatRake2, not Target:IsInMeleeRange(5)) then return "rake cat 40"; end
  end
  -- shred,if=combo_points<5|energy>90
  if S.Shred:IsReady() and (Player:ComboPoints() < 5 or Player:Energy() > 90) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(5)) then return "shred cat 42"; end
  end
end

local function Owl()
  -- heart_of_the_wild,if=(cooldown.convoke_the_spirits.remains<30|cooldown.convoke_the_spirits.remains>90|!covenant.night_fae)&!buff.heart_of_the_wild.up
  if S.HeartoftheWild:IsCastable() and CDsON() and ((S.ConvoketheSpirits:CooldownRemains() < 30 or S.ConvoketheSpirits:CooldownRemains() > 90 or CovenantID ~= 3) and Player:BuffDown(S.HeartoftheWildBuff)) then
    if Cast(S.HeartoftheWild, Settings.Restoration.GCDasOffGCD.HeartOfTheWild) then return "heart_of_the_wild owl 2"; end
  end
  -- cat_form,if=runeforge.oath_of_the_elder_druid&!buff.oath_of_the_elder_druid.up
  if S.CatForm:IsReady() and (ElderDruidEquipped and Player:BuffDown(S.OathoftheElderDruidBuff)) then
    if Cast(S.CatForm) then return "cat_form owl 4"; end
  end
  -- moonkin_form,if=!buff.moonkin_form.up
  if S.MoonkinForm:IsReady() and (Player:BuffDown(S.MoonkinForm)) then
    if Cast(S.MoonkinForm) then return "moonkin_form owl 6"; end
  end
  -- convoke_the_spirits,if=(buff.heart_of_the_wild.up|cooldown.heart_of_the_wild.remains>60-30*runeforge.celestial_spirits|!talent.heart_of_the_wild.enabled)&(buff.eclipse_solar.remains>4|buff.eclipse_lunar.remains>4)&(!equipped.soulleting_ruby|cooldown.soulleting_ruby.remains<114-60*runeforge.celestial_spirits&!cooldown.soulleting_ruby.ready)
  if S.ConvoketheSpirits:IsCastable() and CDsON() and ((Player:BuffUp(S.HeartoftheWildBuff) or S.HeartoftheWild:CooldownRemains() > 60 - 30 * num(CelestialSpiritsEquipped) or not S.HeartoftheWild:IsAvailable()) and (Player:BuffRemains(S.EclipseSolar) > 4 or Player:BuffRemains(S.EclipseLunar) > 4) and ((not I.SoullettingRuby:IsEquipped()) or I.SoullettingRuby:CooldownRemains() < 114 - 60 * num(CelestialSpiritsEquipped) and not I.SoullettingRuby:IsReady())) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(35)) then return "convoke_the_spirits owl 8"; end
  end
  -- ravenous_frenzy,if=(buff.heart_of_the_wild.up|cooldown.heart_of_the_wild.remains>60|!talent.heart_of_the_wild.enabled)
  if S.RavenousFrenzy:IsCastable() and CDsON() and (Player:BuffUp(S.HeartoftheWildBuff) or S.HeartoftheWild:CooldownRemains() > 60 or not S.HeartoftheWild:IsAvailable()) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Signature) then return "ravenous_frenzy owl 10"; end
  end
  -- kindred_spirits,if=(buff.heart_of_the_wild.up|cooldown.heart_of_the_wild.remains>60|!talent.heart_of_the_wild.enabled)
  if S.KindredSpirits:IsCastable() and (Player:BuffUp(S.HeartoftheWildBuff) or S.HeartoftheWild:CooldownRemains() > 60 or not S.HeartoftheWild:IsAvailable()) then
    if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Signature) then return "kindred_spirits owl 12"; end
  end
  -- starsurge,if=spell_targets.starfire<6|!eclipse.in_lunar&spell_targets.starfire<8
  if S.Starsurge:IsReady() and (EnemiesCount8ySplash < 6 or (not EclipseInLunar) and EnemiesCount8ySplash < 8) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge owl 14"; end
  end
  -- moonfire,target_if=refreshable&target.time_to_die>5&(spell_targets.starfire<5|!eclipse.in_lunar&spell_targets.starfire<7)
  if S.Moonfire:IsReady() and (EnemiesCount8ySplash < 5 or (not EclipseInLunar) and EnemiesCount8ySplash < 7) then
    if Everyone.CastCycle(S.Moonfire, Enemies8ySplash, EvaluateCycleOwlDoT, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire owl 16"; end
  end
  -- sunfire,target_if=refreshable&target.time_to_die>5
  if S.Sunfire:IsReady() then
    if Everyone.CastCycle(S.Sunfire, Enemies8ySplash, EvaluateCycleOwlDoT, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire owl 18"; end
  end
  -- wrath,if=eclipse.in_solar&spell_targets.starfire=1|eclipse.lunar_next|eclipse.any_next&spell_targets.starfire>1
  if S.Wrath:IsReady() and (EclipseInSolar and EnemiesCount8ySplash == 1 or EclipseLunarNext or EclipseAnyNext and EnemiesCount8ySplash > 1) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath owl 20"; end
  end
  -- starfire
  if S.Starfire:IsReady() then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire owl 22"; end
  end
end

local function Healing()
  -- strict_sequence,name=heal:rejuvenation:rejuvenation:rejuvenation:rejuvenation
  -- Note: We're not handling healing...
end

local function APL()
  -- Enemies Update
  if AoEON() then
    Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
    EnemiesCount8ySplash = #Enemies8ySplash
  else
    Enemies8ySplash = {}
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- Eclipse Check
    EclipseCheck()
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- berserking
    if CDsON() and S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 2"; end
    end
    -- run_action_list,name=healing,if=!buff.prowl.up&!buff.shadowmeld.up&druid.time_spend_healing,line_cd=15
    -- Note: We're not handling healing...
    -- use_items,if=!buff.prowl.up&!buff.shadowmeld.up
    if (not Player:BuffUp(S.Prowl)) and (not Player:BuffUp(S.Shadowmeld)) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- potion
    if Settings.Commons.Enabled.Potions and I.PotionofSpectralIntellect:IsReady() then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
    end
    -- run_action_list,name=cat,if=talent.feral_affinity.enabled
    if S.FeralAffinity:IsAvailable() then
      local ShouldReturn = Cat(); if ShouldReturn then return ShouldReturn; end
    end
    if CovenantID == 4 then
      -- adaptive_swarm,target_if=dot.adaptive_swarm_damage.stack=2&dot.adaptive_swarm_damage.remains>2
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmCount2, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm main 6"; end
      end
      -- adaptive_swarm,target_if=min:dot.adaptive_swarm_damage.stack,if=dot.adaptive_swarm_damage.remains>2
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastTargetIf(S.AdaptiveSwarm, Enemies8ySplash, "min", EvaluateTargetIfFilterAdaptiveSwarm, EvaluateTargetIfAdaptiveSwarm, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm main 8"; end
      end
      -- adaptive_swarm,target_if=dot.adaptive_swarm_damage.stack=1&dot.adaptive_swarm_damage.remains>2
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmCount1, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm main 10"; end
      end
      -- adaptive_swarm,target_if=dot.adaptive_swarm_damage.stack=3&dot.adaptive_swarm_damage.remains>2
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmCount3, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm main 12"; end
      end
      -- adaptive_swarm,target_if=dot.adaptive_swarm_damage.stack=4&dot.adaptive_swarm_damage.remains>2
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmCount4, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm main 14"; end
      end
      -- adaptive_swarm,target_if=!dot.adaptive_swarm_damage.ticking
      if S.AdaptiveSwarm:IsCastable() then
        if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmDown, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Signature) then return "adaptive_swarm main 16"; end
      end
    end
    -- run_action_list,name=owl,if=talent.balance_affinity.enabled
    if S.BalanceAffinity:IsAvailable() then
      local ShouldReturn = Owl(); if ShouldReturn then return ShouldReturn; end
    end
    -- convoke_the_spirits,if=(buff.heart_of_the_wild.up|cooldown.heart_of_the_wild.remains>60-30*runeforge.celestial_spirits|!talent.heart_of_the_wild.enabled)&(!equipped.soulleting_ruby|cooldown.soulleting_ruby.remains<114&!cooldown.soulleting_ruby.ready)
    if S.ConvoketheSpirits:IsCastable() and CDsON() and ((Player:BuffUp(S.HeartoftheWildBuff) or S.HeartoftheWild:CooldownRemains() > 60 - 30 * num(CelestialSpiritsEquipped) or not S.HeartoftheWild:IsAvailable()) and ((not I.SoullettingRuby:IsEquipped()) or I.SoullettingRuby:CooldownRemains() < 114 and not I.SoullettingRuby:IsReady())) then
      if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(35)) then return "convoke_the_spirits main 18"; end
    end
    if (Player:BuffUp(S.HeartoftheWildBuff) or S.HeartoftheWild:CooldownRemains() > 60 or not S.HeartoftheWild:IsAvailable()) then
      -- ravenous_frenzy,if=(buff.heart_of_the_wild.up|cooldown.heart_of_the_wild.remains>60|!talent.heart_of_the_wild.enabled)
      if S.RavenousFrenzy:IsCastable() and CDsON() then
        if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(40)) then return "ravenous_frenzy main 20"; end
      end
      -- kindred_spirits,if=(buff.heart_of_the_wild.up|cooldown.heart_of_the_wild.remains>60|!talent.heart_of_the_wild.enabled)
      if S.KindredSpirits:IsCastable() then
        if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Signature) then return "kindred_spirits main 22"; end
      end
    end
    -- sunfire,target_if=refreshable
    if S.Sunfire:IsReady() and (Target:DebuffRefreshable(S.SunfireDebuff)) then
      if Cast(S.Sunfire, nil, nil, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire main 24"; end
    end
    -- moonfire,target_if=refreshable
    if S.Moonfire:IsReady() and (Target:DebuffRefreshable(S.MoonfireDebuff)) then
      if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire main 26"; end
    end
    -- wrath
    if S.Wrath:IsReady() and not Player:BuffUp(S.CatForm) then
      if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath main 28"; end
    end
    -- moonfire
    if S.Moonfire:IsReady() and not Player:BuffUp(S.CatForm) then
      if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire main 30"; end
    end
    -- Manually added: Pool if nothing to do
    if (true) then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
    end
  end
end

local function OnInit()
  HR.Print("Restoration Druid rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(105, APL, OnInit)
