--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC         = HeroDBC.DBC
-- HeroLib
local HL          = HeroLib
local Cache       = HeroCache
local Unit        = HL.Unit
local Player      = Unit.Player
local Pet         = Unit.Pet
local Target      = Unit.Target
local Spell       = HL.Spell
local MultiSpell  = HL.MultiSpell
local Item        = HL.Item
-- HeroRotation
local HR          = HeroRotation
local AoEON       = HR.AoEON
local CDsON       = HR.CDsON
local Cast        = HR.Cast
-- Num/Bool Helper Functions
local num         = HR.Commons.Everyone.num
local bool        = HR.Commons.Everyone.bool
-- lua
local mathmax     = math.max
-- WoW API
local Delay       = C_Timer.After

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Define S/I for spell and item arrays
local S = Spell.Druid.Balance
local I = Item.Druid.Balance

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.SpymastersWeb:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Druid = HR.Commons.Druid
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  CommonsDS = HR.GUISettings.APL.Druid.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Druid.CommonsOGCD,
  Balance = HR.GUISettings.APL.Druid.Balance
}

--- ===== Rotation Variables =====
local VarPassiveAsp
local VarNoCDTalent
local VarEclipse, VarEclipseRemains
local VarEnterLunar, VarBoatStacks
local VarConvokeCondition
local CAIncBuffUp
local CAIncBuffRemains
local CAInc = S.IncarnationTalent:IsAvailable() and S.Incarnation or S.CelestialAlignment
local IsInSpellRange = false
local Enemies10ySplash, EnemiesCount10ySplash
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Level, VarTrinket2Level
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarOnUseTrinket
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData()

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.Level == 0 or T2.Level == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
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

  VarTrinket1Level = T1.Level
  VarTrinket2Level = T2.Level

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1BL = T1.Blacklisted
  VarTrinket2BL = T2.Blacklisted

  local T1Test = (Trinket1:HasUseBuff() and VarTrinket1CD > 0 or VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket1ID == I.SignetofthePriory:ID()) and VarTrinket1ID ~= I.ArakaraSacbrood:ID()
  local T2Test = (Trinket2:HasUseBuff() and VarTrinekt2CD > 0 or VarTrinket2ID == I.SpymastersWeb:ID() or VarTrinket2ID == I.SignetofthePriory:ID()) and VarTrinket2ID ~= I.ArakaraSacbrood:ID()
  VarOnUseTrinket = 0 + num(T1Test) + num(T2Test)
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  CAInc = S.IncarnationTalent:IsAvailable() and S.Incarnation or S.CelestialAlignment
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function EnergizeAmount(Spell)
  local TotalAsp = 0
  if Spell == S.Wrath then
    -- Calculate Wrath AsP
    TotalAsp = 8
    if S.WildSurges:IsAvailable() then
      TotalAsp = TotalAsp + 2
    end
    if S.SouloftheForest:IsAvailable() and Player:BuffUp(S.EclipseSolar) then
      TotalAsp = TotalAsp * 1.6
    end
  elseif Spell == S.Starfire then
    -- Calculate Starfire AsP
    TotalAsp = 10
    if S.WildSurges:IsAvailable() then
      TotalAsp = TotalAsp + 2
    end
    if Player:BuffUp(S.WarriorofEluneBuff) then
      TotalAsp = TotalAsp * 1.4
    end
    if S.SouloftheForest:IsAvailable() and Player:BuffUp(S.EclipseLunar) then
      local SotFBonus = (1 + 0.2 * EnemiesCount10ySplash)
      if SotFBonus > 1.6 then SotFBonus = 1.6 end
      TotalAsp = TotalAsp * SotFBonus
    end
  elseif Spell == S.Moonfire then
    -- Calculate Moonfire AsP
    TotalAsp = 6
    if S.MoonGuardian:IsAvailable() then
      TotalAsp = TotalAsp + 2
    end
  elseif Spell == S.Sunfire then
    -- Calculate Sunfire AsP
    TotalAsp = 6
  elseif Spell == S.NewMoon then
    -- Calculate New Moon AsP
    TotalAsp = 10
  elseif Spell == S.HalfMoon then
    -- Calculate Half Moon AsP
    TotalAsp = 20
  elseif Spell == S.FullMoon then
    -- Calculate Full Moon AsP
    TotalAsp = 40
  end
  return TotalAsp
end

--- ===== CastCycle Functions =====
local function EvaluateCycleMoonfireAoE(TargetUnit)
  -- target_if=refreshable&(target.time_to_die-remains)>6&astral_power.deficit>variable.passive_asp+energize_amount
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and (TargetUnit:TimeToDie() - Target:DebuffRemains(S.MoonfireDebuff)) > 6 and Player:AstralPowerDeficit() > VarPassiveAsp + S.Moonfire:EnergizeAmount())
end

local function EvaluateCycleMoonfireST(TargetUnit)
  -- target_if=remains<3&(!talent.treants_of_the_moon|cooldown.force_of_nature.remains>3&!buff.harmony_of_the_grove.up)
  return TargetUnit:DebuffRemains(S.MoonfireDebuff) < 3 and (not S.TreantsoftheMoon:IsAvailable() or S.ForceofNature:CooldownRemains() > 3 and Player:BuffDown(S.HarmonyoftheGroveBuff))
end

local function EvaluateCycleMoonfireST2(TargetUnit)
  -- target_if=refreshable&(!talent.treants_of_the_moon|cooldown.force_of_nature.remains>3&!buff.harmony_of_the_grove.up)
  return TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and (not S.TreantsoftheMoon:IsAvailable() or S.ForceofNature:CooldownRemains() > 3 and Player:BuffDown(S.HarmonyoftheGroveBuff))
end

local function EvaluateCycleStellarFlareAoE(TargetUnit)
  -- target_if=refreshable&(target.time_to_die-remains-target>7+spell_targets)
  return TargetUnit:DebuffRefreshable(S.StellarFlareDebuff) and (TargetUnit:TimeToDie() - TargetUnit:DebuffRemains(S.StellarFlareDebuff) > 7 + EnemiesCount10ySplash)
end

local function EvaluateCycleStellarFlareST(TargetUnit)
  -- target_if=refreshable&(target.time_to_die-remains-target>7+spell_targets)
  return TargetUnit:DebuffRefreshable(S.StellarFlareDebuff) and (TargetUnit:TimeToDie() - TargetUnit:DebuffRemains(S.StellarFlareDebuff) > 7 + EnemiesCount10ySplash)
end

local function EvaluateCycleSunfireAoE(TargetUnit)
  -- target_if=refreshable&(target.time_to_die-remains)>6-(spell_targets%2)&astral_power.deficit>variable.passive_asp+energize_amount
  return (TargetUnit:DebuffRefreshable(S.SunfireDebuff) and (TargetUnit:TimeToDie() - Target:DebuffRemains(S.SunfireDebuff)) > 6 - (EnemiesCount10ySplash / 2) and Player:AstralPowerDeficit() > VarPassiveAsp + S.Sunfire:EnergizeAmount())
end

local function EvaluateCycleSunfireST(TargetUnit)
  -- target_if=remains<3
  return TargetUnit:DebuffRemains(S.SunfireDebuff) < 3
end

local function EvaluateCycleSunfireST2(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.SunfireDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=no_cd_talent,value=!talent.celestial_alignment&!talent.incarnation_chosen_of_elune|druid.no_cds
  -- variable,name=on_use_trinket,value=0
  -- variable,name=on_use_trinket,op=add,value=(trinket.1.has_proc.any&trinket.1.cooldown.duration|trinket.1.is.spymasters_web|trinket.1.is.signet_of_the_priory)&!trinket.1.is.arakara_sacbrood
  -- variable,name=on_use_trinket,op=add,value=((trinket.2.has_proc.any&trinket.2.cooldown.duration|trinket.2.is.spymasters_web|trinket.2.is.signet_of_the_priory)*2&!trinket.2.is.arakara_sacbrood)
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and Everyone.GroupBuffMissing(S.MarkoftheWildBuff) then
    if Cast(S.MarkoftheWild, Settings.CommonsOGCD.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat"; end
  end
  -- moonkin_form
  if S.MoonkinForm:IsCastable() then
    if Cast(S.MoonkinForm) then return "moonkin_form precombat"; end
  end
  -- wrath
  if S.Wrath:IsCastable() and not Player:IsCasting(S.Wrath) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath precombat 2"; end
  end
  -- wrath
  if S.Wrath:IsCastable() and (Player:IsCasting(S.Wrath) and S.Wrath:Count() == 2 or Player:PrevGCD(1, S.Wrath) and S.Wrath:Count() == 1) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath precombat 4"; end
  end
  -- wait,sec=0.1,if=hero_tree.keeper_of_the_grove&!talent.stellar_flare
  -- starfire,if=!talent.stellar_flare&hero_tree.elunes_chosen
  if S.Starfire:IsCastable() and (not S.StellarFlare:IsAvailable() and Player:HeroTreeID() == 24) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire precombat 6"; end
  end
  -- stellar_flare
  if S.StellarFlare:IsCastable() then
    if Cast(S.StellarFlare, nil, nil, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare precombat 8"; end
  end
end

local function AoE()
  local DungeonRoute = Player:IsInDungeonArea()
  -- moonfire,target_if=refreshable&(target.time_to_die-remains)>6&astral_power.deficit>variable.passive_asp+energize_amount,if=fight_style.dungeonroute
  if S.Moonfire:IsCastable() and (DungeonRoute) then
    if Everyone.CastCycle(S.Moonfire, Enemies10ySplash, EvaluateCycleMoonfireAoE, not IsInSpellRange) then return "moonfire aoe 2"; end
  end
  -- sunfire,target_if=refreshable&(target.time_to_die-remains)>6-(spell_targets%2)&astral_power.deficit>variable.passive_asp+energize_amount
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies10ySplash, EvaluateCycleSunfireAoE, not IsInSpellRange) then return "sunfire aoe 4"; end
  end
  -- moonfire,target_if=refreshable&(target.time_to_die-remains)>6&astral_power.deficit>variable.passive_asp+energize_amount,if=!fight_style.dungeonroute
  if S.Moonfire:IsCastable() and (not DungeonRoute) then
    if Everyone.CastCycle(S.Moonfire, Enemies10ySplash, EvaluateCycleMoonfireAoE, not IsInSpellRange) then return "moonfire aoe 6"; end
  end
  -- stellar_flare,target_if=refreshable&(target.time_to_die-remains-target>7+spell_targets),if=spell_targets<(11-talent.umbral_intensity.rank-(2*talent.astral_smolder)-talent.lunar_calling)
  if S.StellarFlare:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + S.StellarFlare:EnergizeAmount() and EnemiesCount10ySplash < (11 - S.UmbralIntensity:TalentRank() - S.AstralSmolder:TalentRank()) and VarCDConditionAoE) then
    if Everyone.CastCycle(S.StellarFlare, Enemies10ySplash, EvaluateCycleStellarFlareAoE, not IsInSpellRange) then return "stellar_flare aoe 8"; end
  end
  -- force_of_nature,if=(talent.power_of_the_dream&talent.early_spring&talent.orbital_strike)|variable.eclipse_remains>=3
  if S.ForceofNature:IsCastable() and ((S.PoweroftheDream:IsAvailable() and S.EarlySpring:IsAvailable() and S.OrbitalStrike:IsAvailable()) or VarEclipseRemains >= 3) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature) then return "force_of_nature aoe 10"; end
  end
  -- fury_of_elune,if=variable.eclipse
  if S.FuryofElune:IsCastable() and (VarEclipse) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune, nil, not IsInSpellRange) then return "fury_of_elune aoe 12"; end
  end
  if CDsON() then
    -- celestial_alignment,if=fight_remains<15*(1+talent.greater_alignment*0.4)|(!hero_tree.keeper_of_the_grove|(buff.harmony_of_the_grove.up|cooldown.force_of_nature.remains>25))
    if S.CelestialAlignment:IsCastable() and (BossFightRemains < 15 * (1 + num(S.GreaterAlignment:IsAvailable()) * 0.4) or (Player:HeroTreeID() ~= 23 or (Player:BuffUp(S.HarmonyoftheGroveBuff) or S.ForceofNature:CooldownRemains() > 25))) then
      if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CAInc) then return "celestial_alignment aoe 14"; end
    end
    -- incarnation,if=fight_remains<20*(1+talent.greater_alignment*0.4)|(!hero_tree.keeper_of_the_grove|(buff.harmony_of_the_grove.up|cooldown.force_of_nature.remains>25))
    if S.Incarnation:IsCastable() and (BossFightRemains < 20 * (1 + num(S.GreaterAlignment:IsAvailable()) * 0.4) or (Player:HeroTreeID() ~= 23 or (Player:BuffUp(S.HarmonyoftheGroveBuff) or S.ForceofNature:CooldownRemains() > 25))) then
      if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CAInc) then return "celestial_alignment aoe 16"; end
    end
  end
  -- warrior_of_elune,if=!talent.lunar_calling&buff.eclipse_solar.remains<7|talent.lunar_calling
  if S.WarriorofElune:IsCastable() and (not S.LunarCalling:IsAvailable() and Player:BuffRemains(S.EclipseSolar) < 7 or S.LunarCalling:IsAvailable()) then
    if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorOfElune) then return "warrior_of_elune aoe 18"; end
  end
  -- starfire,if=(!talent.lunar_calling&spell_targets.starfire=1)&(buff.eclipse_solar.up&buff.eclipse_solar.remains<action.starfire.cast_time|eclipse.in_none)
  if S.Starfire:IsCastable() and ((not S.LunarCalling:IsAvailable() and EnemiesCount10ySplash == 1) and (Player:BuffUp(S.EclipseSolar) and Player:BuffRemains(S.EclipseSolar) < S.Starfire:CastTime() or not VarEclipse)) then
    if Cast(S.Starfire, nil, nil, not IsInSpellRange) then return "starfire aoe 20"; end
  end
  -- starfall,if=buff.starweavers_warp.up|buff.touch_the_cosmos_starfall.up
  if S.Starfall:IsReady() and (Player:BuffUp(S.StarweaversWarp) or Player:BuffUp(S.TouchtheCosmosStarfall)) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not IsInSpellRange) then return "starfall aoe 22"; end
  end
  -- starsurge,if=buff.starweavers_weft.up|buff.touch_the_cosmos_starsurge.up
  if S.Starsurge:IsReady() and (Player:BuffUp(S.StarweaversWeft) or Player:BuffUp(S.TouchtheCosmosStarsurge)) then
    if Cast(S.Starsurge, nil, nil, not IsInSpellRange) then return "starsurge aoe 24"; end
  end
  -- starfall
  if S.Starfall:IsReady() then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not IsInSpellRange) then return "starfall aoe 26"; end
  end
  -- convoke_the_spirits,if=spell_targets.starfire<(7-talent.umbral_intensity-talent.umbral_embrace-talent.soul_of_the_forest)&(fight_remains<5|(buff.ca_inc.up|cooldown.ca_inc.remains>40)&(!hero_tree.keeper_of_the_grove|buff.harmony_of_the_grove.up|cooldown.force_of_nature.remains>15))
  if CDsON() and S.ConvoketheSpirits:IsCastable() and (EnemiesCount10ySplash < (7 - num(S.UmbralIntensity:IsAvailable()) - num(S.UmbralEmbrace:IsAvailable()) - num(S.SouloftheForest:IsAvailable())) and (BossFightRemains < 5 or (CAIncBuffUp or CAInc:CooldownRemains() > 40) and (Player:HeroTreeID() ~= 23 or Player:BuffUp(S.HarmonyoftheGroveBuff) or S.ForceofNature:CooldownRemains() > 15))) then
    if Cast(S.ConvoketheSpirits, nil, Settings.CommonsDS.DisplayStyle.ConvokeTheSpirits, not IsInSpellRange) then return "convoke_the_spirits aoe 28"; end
  end
  -- new_moon
  if S.NewMoon:IsCastable() then
    if Cast(S.NewMoon, nil, nil, not IsInSpellRange) then return "new_moon aoe 30"; end
  end
  -- half_moon
  if S.HalfMoon:IsCastable() then
    if Cast(S.HalfMoon, nil, nil, not IsInSpellRange) then return "half_moon aoe 32"; end
  end
  -- full_moon
  if S.FullMoon:IsCastable() then
    if Cast(S.FullMoon, nil, nil, not IsInSpellRange) then return "full_moon aoe 34"; end
  end
  -- wild_mushroom
  if S.WildMushroom:IsCastable() then
    if Cast(S.WildMushroom, Settings.Balance.GCDasOffGCD.WildMushroom, nil, not IsInSpellRange) then return "wild_mushroom aoe 36"; end
  end
  -- starfire,if=talent.lunar_calling|buff.eclipse_lunar.up&spell_targets.starfire>1
  if S.Starfire:IsCastable() and (S.LunarCalling:IsAvailable() or Player:BuffUp(S.EclipseLunar) and EnemiesCount10ySplash > 1) then
    if Cast(S.Starfire, nil, nil, not IsInSpellRange) then return "starfire aoe 38"; end
  end
  -- wrath
  if S.Wrath:IsCastable() then
    if Cast(S.Wrath, nil, nil, not IsInSpellRange) then return "wrath aoe 40"; end
  end
end

local function ST()
  -- sunfire,target_if=remains<3
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies10ySplash, EvaluateCycleSunfireST, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire st 2"; end
  end
  -- moonfire,target_if=remains<3&(!talent.treants_of_the_moon|cooldown.force_of_nature.remains>3&!buff.harmony_of_the_grove.up)
  if S.Moonfire:IsCastable() then
    if Everyone.CastCycle(S.Moonfire, Enemies10ySplash, EvaluateCycleMoonfireST, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire st 4"; end
  end
  if CDsON() then
    -- celestial_alignment,if=fight_remains<15*(1+talent.greater_alignment*0.4)|!hero_tree.keeper_of_the_grove|(buff.harmony_of_the_grove.up|cooldown.force_of_nature.remains>25)
    if S.CelestialAlignment:IsCastable() and (BossFightRemains < 15 * (1 + num(S.GreaterAlignment:IsAvailable()) * 0.4) or (Player:HeroTreeID() ~= 23 or (Player:BuffUp(S.HarmonyoftheGroveBuff) or S.ForceofNature:CooldownRemains() > 25))) then
      if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CAInc) then return "celestial_alignment st 6"; end
    end
    -- incarnation,if=fight_remains<20*(1+talent.greater_alignment*0.4)|!hero_tree.keeper_of_the_grove|(buff.harmony_of_the_grove.up|cooldown.force_of_nature.remains>25)
    if S.Incarnation:IsCastable() and (BossFightRemains < 20 * (1 + num(S.GreaterAlignment:IsAvailable()) * 0.4) or (Player:HeroTreeID() ~= 23 or (Player:BuffUp(S.HarmonyoftheGroveBuff) or S.ForceofNature:CooldownRemains() > 25))) then
      if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CAInc) then return "celestial_alignment st 8"; end
    end
  end
  -- force_of_nature,if=cooldown.ca_inc.remains<gcd.max&(!talent.natures_grace|!variable.eclipse|variable.eclipse_remains>6)|variable.eclipse_remains>=3&cooldown.ca_inc.remains>10+15*talent.control_of_the_dream&(fight_remains>cooldown+5|cooldown.ca_inc.remains>fight_remains)
  if S.ForceofNature:IsCastable() and (CAInc:CooldownRemains() < Player:GCD() and (not S.NaturesGrace:IsAvailable() or not VarEclipse or VarEclipseRemains > 6) or VarEclipseRemains >= 3 and CAInc:CooldownRemains() > 10 + 15 * num(S.ControloftheDream:IsAvailable()) and (BossFightRemains > CAInc:CooldownRemains() + 5 or CAInc:CooldownRemains() > BossFightRemains)) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature) then return "force_of_nature st 10"; end
  end
  -- fury_of_elune,if=5+variable.passive_asp<astral_power.deficit
  if S.FuryofElune:IsCastable() and (5 + VarPassiveAsp < Player:AstralPowerDeficit()) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune) then return "fury_of_elune st 12"; end
  end
  -- starsurge,if=talent.starlord&buff.starlord.stack<3
  if S.Starsurge:IsReady() and (S.Starlord:IsAvailable() and Player:BuffStack(S.StarlordBuff) < 3) then
    if Cast(S.Starsurge, nil, nil, not IsInSpellRange) then return "starsurge st 14"; end
  end
  -- sunfire,target_if=refreshable
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies10ySplash, EvaluateCycleSunfireST2, not IsInSpellRange) then return "sunfire st 16"; end
  end
  -- moonfire,target_if=refreshable&(!talent.treants_of_the_moon|cooldown.force_of_nature.remains>3&!buff.harmony_of_the_grove.up)
  if S.Moonfire:IsCastable() then
    if Everyone.CastCycle(S.Moonfire, Enemies10ySplash, EvaluateCycleMoonfireST2, not IsInSpellRange) then return "moonfire st 18"; end
  end
  -- stellar_flare,target_if=refreshable&(target.time_to_die-remains-target>7+spell_targets)
  if S.StellarFlare:IsCastable() then
    if Everyone.CastCycle(S.StellarFlare, Enemies10ySplash, EvaluateCycleStellarFlareST, not IsInSpellRange) then return "stellar_flare st 20"; end
  end
  -- variable,name=convoke_condition,value=fight_remains<5|(buff.ca_inc.up|cooldown.ca_inc.remains>40)&(!hero_tree.keeper_of_the_grove|buff.harmony_of_the_grove.up|cooldown.force_of_nature.remains>15)
  VarConvokeCondition = (BossFightRemains < 5 or (CAIncBuffUp or CAInc:CooldownRemains() > 40) and (Player:HeroTreeID() ~= 23 or Player:BuffUp(S.HarmonyoftheGroveBuff) or S.ForceofNature:CooldownRemains() > 15))
  -- starsurge,if=cooldown.convoke_the_spirits.remains<gcd.max*2&variable.convoke_condition
  if S.Starsurge:IsReady() and (S.ConvoketheSpirits:CooldownRemains() < Player:GCD() * 2 and VarConvokeCondition) then
    if Cast(S.Starsurge, nil, nil, not IsInSpellRange) then return "starsurge st 22"; end
  end
  -- convoke_the_spirits,if=variable.convoke_condition
  if S.ConvoketheSpirits:IsCastable() and (VarConvokeCondition) then
    if Cast(S.ConvoketheSpirits, nil, Settings.CommonsDS.DisplayStyle.ConvokeTheSpirits, not IsInSpellRange) then return "convoke_the_spirits st 24"; end
  end
  -- starsurge,if=buff.starlord.remains>4&variable.boat_stacks>=3|fight_remains<4
  if S.Starsurge:IsReady() and (Player:BuffRemains(S.StarlordBuff) > 4 and VarBoatStacks >= 3 or BossFightRemains < 4) then
    if Cast(S.Starsurge, nil, nil, not IsInSpellRange) then return "starsurge st 26"; end
  end
  -- new_moon,if=astral_power.deficit>variable.passive_asp+energize_amount|fight_remains<20|cooldown.ca_inc.remains>15
  if S.NewMoon:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + EnergizeAmount(S.NewMoon) or BossFightRemains < 20 or CAInc:CooldownRemains() > 15) then
    if Cast(S.NewMoon, nil, nil, not IsInSpellRange) then return "new_moon st 28"; end
  end
  -- half_moon,if=astral_power.deficit>variable.passive_asp+energize_amount&(buff.eclipse_lunar.remains>execute_time|buff.eclipse_solar.remains>execute_time)|fight_remains<20|cooldown.ca_inc.remains>15
  if S.HalfMoon:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + EnergizeAmount(S.HalfMoon) and (Player:BuffRemains(S.EclipseLunar) > S.HalfMoon:ExecuteTime() or Player:BuffRemains(S.EclipseSolar) > S.HalfMoon:ExecuteTime()) or BossFightRemains < 20 or CAInc:CooldownRemains() > 15) then
    if Cast(S.HalfMoon, nil, nil, not IsInSpellRange) then return "half_moon st 30"; end
  end
  -- full_moon,if=astral_power.deficit>variable.passive_asp+energize_amount&(buff.eclipse_lunar.remains>execute_time|buff.eclipse_solar.remains>execute_time)|fight_remains<20|cooldown.ca_inc.remains>15
  if S.FullMoon:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + EnergizeAmount(S.FullMoon) and (Player:BuffRemains(S.EclipseLunar) > S.FullMoon:ExecuteTime() or Player:BuffRemains(S.EclipseSolar) > S.FullMoon:ExecuteTime()) or BossFightRemains < 20 or CAInc:CooldownRemains() > 15) then
    if Cast(S.FullMoon, nil, nil, not IsInSpellRange) then return "full_moon st 32"; end
  end
  -- starsurge,if=buff.starweavers_weft.up|buff.touch_the_cosmos_starsurge.up
  if S.Starsurge:IsReady() and (Player:BuffUp(S.StarweaversWeft) or Player:BuffUp(S.TouchtheCosmosStarsurge)) then
    if Cast(S.Starsurge, nil, nil, not IsInSpellRange) then return "starsurge st 34"; end
  end
  -- starfall,if=buff.starweavers_warp.up|buff.touch_the_cosmos_starfall.up
  if S.Starfall:IsReady() and (Player:BuffUp(S.StarweaversWarp) or Player:BuffUp(S.TouchtheCosmosStarfall)) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not IsInSpellRange) then return "starfall st 36"; end
  end
  -- starsurge,if=astral_power.deficit<variable.passive_asp+action.wrath.energize_amount+(action.starfire.energize_amount+variable.passive_asp)*(buff.eclipse_solar.remains<(gcd.max*3))
  if S.Starsurge:IsReady() and (Player:AstralPowerDeficit() < VarPassiveAsp + EnergizeAmount(S.Wrath) + (EnergizeAmount(S.Starfire) + VarPassiveAsp) * (num(Player:BuffRemains(S.EclipseSolar) < Player:GCD() * 3))) then
    if Cast(S.Starsurge, nil, nil, not IsInSpellRange) then return "starsurge st 38"; end
  end
  -- force_of_nature,if=!hero_tree.keeper_of_the_grove
  if S.ForceofNature:IsCastable() and (Player:HeroTreeID() ~= 23) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature) then return "force_of_nature st 40"; end
  end
  -- starfire,if=talent.lunar_calling
  if S.Starfire:IsCastable() and (S.LunarCalling:IsAvailable()) then
    if Cast(S.Starfire, nil, nil, not IsInSpellRange) then return "starfire st 42"; end
  end
  -- wrath
  if S.Wrath:IsCastable() then
    if Cast(S.Wrath, nil, nil, not IsInSpellRange) then return "wrath st 44"; end
  end
end

--- ===== APL Main =====
local function APL()
  -- Unit Update
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

    -- Check CA/Incarnation Buff Status
    CAIncBuffUp = Player:BuffUp(S.CABuff) or Player:BuffUp(S.IncarnationBuff)
    CAIncBuffRemains = 0
    if CAIncBuffUp then
      CAIncBuffRemains = S.IncarnationTalent:IsAvailable() and Player:BuffRemains(S.IncarnationBuff) or Player:BuffRemains(S.CABuff)
    end

    -- We use Wrath to check range for a lot of spells, so let's make a variable for it.
    IsInSpellRange = Target:IsSpellInRange(S.Wrath)
  end

  -- Moonkin Form OOC, if setting is true
  if S.MoonkinForm:IsCastable() and Settings.Balance.ShowMoonkinFormOOC then
    if Cast(S.MoonkinForm) then return "moonkin_form ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=passive_asp,value=6%spell_haste+talent.natures_balance+talent.orbit_breaker*dot.moonfire.ticking*(buff.orbit_breaker.stack>(27-2*buff.solstice.up))*24
    VarPassiveAsp = 6 / Player:SpellHaste() + num(S.NaturesBalance:IsAvailable()) + num(S.OrbitBreaker:IsAvailable()) * num(S.MoonfireDebuff:AuraActiveCount() > 0) * num(Druid.OrbitBreakerStacks > (27 - 2 * num(Player:BuffUp(S.SolsticeBuff)))) * 24
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,name=spymasters_web,if=buff.ca_inc.up&buff.spymasters_report.stack>29|fight_remains<20
      if I.SpymastersWeb:IsEquippedAndReady() and (CAIncBuffUp and Player:BuffStack(S.SpymastersReportBuff) > 29 or BossFightRemains < 20) then
        if Cast(I.SpymastersWeb, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web main 2"; end
      end
      -- use_items,slots=trinket1,if=variable.on_use_trinket!=1&!trinket.2.ready_cooldown|(variable.on_use_trinket=1|variable.on_use_trinket=3)&buff.ca_inc.up|variable.no_cd_talent|fight_remains<20|variable.on_use_trinket=0
      if Trinket1:IsReady() and not VarTrinket1BL and (VarOnUseTrinket ~= 1 and Trinket2:CooldownDown() or (VarOnUseTrinket == 1 or VarOnUseTrinket == 3) and CAIncBuffUp or VarNoCDTalent or BossFightRemains < 20 or VarOnUseTrinket == 0) then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_items trinket1 ("..Trinket1:Name()..") main 4"; end
      end
      -- use_items,slots=trinket2,if=variable.on_use_trinket!=2&!trinket.1.ready_cooldown|variable.on_use_trinket=2&buff.ca_inc.up|variable.no_cd_talent|fight_remains<20|variable.on_use_trinket=0
      if Trinket2:IsReady() and not VarTrinket2BL and (VarOnUseTrinket ~= 2 and Trinket1:CooldownDown() or VarOnUseTrinket == 2 and CAIncBuffUp or VarNoCDTalent or BossFightRemains < 20 or VarOnUseTrinket == 0) then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_items trinket2 ("..Trinket2:Name()..") main 6"; end
      end
    end
    -- use_items,if=buff.ca_inc.up
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse and (CAIncBuffUp) then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        local IsTrinket = ItemSlot == 13 or ItemSlot == 14
        if not IsTrinket then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if (IsTrinket and Settings.Commons.Enabled.Trinkets) or (not IsTrinket and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "use_items for "..ItemToUse:Name().." main 8"; end
        end
      end
    end
    -- potion,if=buff.ca_inc.up|fight_remains<=30
    if Settings.Commons.Enabled.Potions and (CAIncBuffUp or BossFightRemains <= 30) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 10"; end
      end
    end
    -- berserking,if=buff.ca_inc.remains>=10|variable.no_cd_talent|fight_remains<15
    if CDsON() and S.Berserking:IsCastable() and (CAIncBuffRemains >= 10 or VarNoCDTalent or BossFightRemains < 15) then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 12"; end
    end
    -- variable,name=eclipse,value=buff.eclipse_lunar.up|buff.eclipse_solar.up
    VarEclipse = Player:BuffUp(S.EclipseLunar) or Player:BuffUp(S.EclipseSolar)
    -- variable,name=eclipse_remains,value=buff.eclipse_lunar.remains<?buff.eclipse_solar.remains
    VarEclipseRemains = mathmax(Player:BuffRemains(S.EclipseLunar), Player:BuffRemains(S.EclipseSolar))
    -- variable,name=enter_lunar,value=talent.lunar_calling|spell_targets.starfire>2-(talent.umbral_intensity.rank+talent.soul_of_the_forest>1)
    VarEnterLunar = S.LunarCalling:IsAvailable() or EnemiesCount10ySplash > 2 - num(S.UmbralIntensity:TalentRank() + num(S.SouloftheForest:IsAvailable()) > 1)
    -- variable,name=boat_stacks,value=buff.balance_of_all_things_arcane.stack+buff.balance_of_all_things_nature.stack
    VarBoatStacks = Player:BuffStack(S.BOATArcaneBuff) + Player:BuffStack(S.BOATNatureBuff)
    -- warrior_of_elune,if=talent.lunar_calling|!talent.lunar_calling&variable.eclipse_remains>=7&cooldown.ca_inc.remains>20
    if S.WarriorofElune:IsCastable() and (S.LunarCalling:IsAvailable() or (VarEclipseRemains >= 7 and CAInc:CooldownRemains() > 20)) then
      if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorOfElune) then return "warrior_of_elune main 14"; end
    end
    -- wrath,if=variable.enter_lunar&(!variable.eclipse|variable.eclipse_remains<cast_time)
    if S.Wrath:IsCastable() and (VarEnterLunar and (not VarEclipse or VarEclipseRemains < S.Wrath:CastTime())) then
      if Cast(S.Wrath, nil, nil, not IsInSpellRange) then return "wrath main 16"; end
    end
    -- starfire,if=!variable.enter_lunar&(!variable.eclipse|variable.eclipse_remains<cast_time)
    if S.Starfire:IsCastable() and (not VarEnterLunar and (not VarEclipse or VarEclipseRemains < S.Starfire:CastTime())) then
      if Cast(S.Starfire, nil, nil, not IsInSpellRange) then return "starfire main 18"; end
    end
    -- call_action_list,name=aoe,if=spell_targets>1
    if AoEON() and EnemiesCount10ySplash > 1 then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st
    local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Pool, if nothing else to do.
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool Resources"; end
  end
end

local function OnInit()
  S.MoonfireDebuff:RegisterAuraTracking()

  HR.Print("Balance Druid rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(102, APL, OnInit)
