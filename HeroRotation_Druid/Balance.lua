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

local S = Spell.Druid.Balance;
local I = Item.Druid.Balance;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount;
local EnemiesFourty
local VarSfTargets = 4

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Balance = HR.GUISettings.APL.Druid.Balance
};

local function num(val)
  if val then return 1 else return 0 end
end

local function FutureAstralPower()
  local AstralPower=Player:AstralPower()
  if not Player:IsCasting() then
    return AstralPower
  else
    if Player:IsCasting(S.NewMoon) then
      return AstralPower + 10
    elseif Player:IsCasting(S.HalfMoon) then
      return AstralPower + 20
    elseif Player:IsCasting(S.FullMoon) then
      return AstralPower + 40
    elseif Player:IsCasting(S.StellarFlare) then
      return AstralPower + 8
    elseif Player:IsCasting(S.SolarWrath) then
      return AstralPower + 8
    elseif Player:IsCasting(S.LunarStrike) then
      return AstralPower + 12
    else
      return AstralPower
    end
  end
end

local function CaInc()
  return S.Incarnation:IsAvailable() and S.Incarnation or S.CelestialAlignment
end

local function AP_Check(spell)
  local APGen = 0
  local CurAP = Player:AstralPower()
  if spell == S.Sunfire or spell == S.Moonfire then 
    APGen = 3
  elseif spell == S.StellarFlare or spell == S.SolarWrath then
    APGen = 8
  elseif spell == S.Incarnation or spell == S.CelestialAlignment then
    APGen = 40
  elseif spell == S.ForceofNature then
    APGen = 20
  elseif spell == S.LunarStrike then
    APGen = 12
  end
  
  if S.ShootingStars:IsAvailable() then 
    APGen = APGen + 4
  end
  if S.NaturesBalance:IsAvailable() then
    APGen = APGen + 2
  end
  
  if CurAP + APGen < Player:AstralPowerMax() then
    return true
  else
    return false
  end
end

local function DoTsUp()
  return (Target:Debuff(S.MoonfireDebuff) and Target:Debuff(S.Sunfire) and (not S.StellarFlare:IsAvailable() or Target:Debuff(S.StellarFlareDebuff)))
end

local function EvaluateCycleSunfire250(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SunfireDebuff)) and (AP_Check(S.Sunfire) and math.floor (TargetUnit:TimeToDie() / (2 * Player:SpellHaste())) * EnemiesCount >= math.ceil (math.floor (2 / EnemiesCount) * 1.5) + 2 * EnemiesCount and (EnemiesCount > 1 + num(S.TwinMoons:IsAvailable()) or TargetUnit:Debuff(S.MoonfireDebuff)) and (Player:BuffDown(CaInc()) or not Player:PrevGCDP(1, S.Sunfire)) and (Player:BuffRemains(CaInc()) > TargetUnit:DebuffRemains(S.SunfireDebuff) or Player:BuffDown(CaInc())))
end

local function EvaluateCycleMoonfire313(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff)) and (AP_Check(S.Moonfire) and math.floor (TargetUnit:TimeToDie() / (2 * Player:SpellHaste())) * EnemiesCount >= 6 and (Player:BuffDown(CaInc()) or not Player:PrevGCDP(1, S.Moonfire)) and (Player:BuffRemains(CaInc()) > TargetUnit:DebuffRemains(S.MoonfireDebuff) or Player:BuffDown(CaInc())))
end

local function EvaluateCycleStellarFlare348(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.StellarFlareDebuff)) and (AP_Check(S.StellarFlare) and math.floor (TargetUnit:TimeToDie() / (2 * Player:SpellHaste())) >= 5 and (Player:BuffDown(CaInc()) or not Player:PrevGCDP(1, S.StellarFlare)) and not Player:IsCasting(S.StellarFlare))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=sf_targets,value=4

  -- moonkin_form
  if S.MoonkinForm:IsCastable() and Player:BuffDown(S.MoonkinForm) then
    if HR.Cast(S.MoonkinForm, Settings.Balance.GCDasOffGCD.MoonkinForm) then return "moonkin_form 39"; end
  end
  -- potion,dynamic_prepot=1
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_intellect 42"; end
  end
  -- solar_wrath
  if S.SolarWrath:IsCastable() and (not Player:PrevGCDP(1, S.SolarWrath) and not Player:PrevGCDP(2, S.SolarWrath)) then
    if HR.Cast(S.SolarWrath, nil, nil, 40) then return "solar_wrath 43"; end
  end
  -- solar_wrath
  if S.SolarWrath:IsCastable() and (Player:PrevGCDP(1, S.SolarWrath) and not Player:PrevGCDP(2, S.SolarWrath)) then
    if HR.Cast(S.SolarWrath, nil, nil, 40) then return "solar_wrath 44"; end
  end
  -- starsurge
  if S.Starsurge:IsReady() then
    if HR.Cast(S.Starsurge, nil, nil, 40) then return "starsurge 45"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesCount = #Player:GetEnemiesInRange(15)
  EnemiesFourty = Player:GetEnemiesInRange(40)

  -- Moonkin Form OOC, if setting is true
  if S.MoonkinForm:IsCastable() and Player:BuffDown(S.MoonkinForm) and Settings.Balance.ShowMoonkinFormOOC then
    if HR.Cast(S.MoonkinForm) then return "moonkin_form ooc"; end
  end
  
  -- call precombat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  
  if Everyone.TargetIsValid() then
    -- Defensives
    if S.Renewal:IsCastable() and Player:HealthPercentage() <= Settings.Balance.RenewalHP then
      if HR.Cast(S.Renewal, Settings.Balance.OffGCDasOffGCD.Renewal) then return "renewal defensive"; end
    end
    if S.Barkskin:IsCastable() and Player:HealthPercentage() <= Settings.Balance.BarkskinHP then
      if HR.Cast(S.Barkskin, Settings.Balance.OffGCDasOffGCD.Barkskin) then return "barkskin defensive"; end
    end
    -- Interrupt
    local ShouldReturn = Everyone.Interrupt(40, S.SolarBeam, Settings.Balance.OffGCDasOffGCD.SolarBeam, false); if ShouldReturn then return ShouldReturn; end
    -- potion,if=buff.celestial_alignment.remains>13|buff.incarnation.remains>16.5
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffRemains(S.CelestialAlignment) > 13 or Player:BuffRemains(S.Incarnation) > 16.5) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_intellect 57"; end
    end
    -- berserking,if=buff.ca_inc.up
    if S.Berserking:IsCastable() and HR.CDsON() and (Player:BuffUp(CaInc())) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 65"; end
    end
    -- blood_of_the_enemy,if=cooldown.ca_inc.remains>30
    if S.BloodoftheEnemy:IsCastable() and (CaInc():CooldownRemains() > 30) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastable() then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast"; end
    end

    -- thorns
    if S.Thorns:IsCastable() then
      if HR.Cast(S.Thorns, nil, Settings.Commons.EssenceDisplayStyle) then return "thorns"; end
    end
    -- use_items,slots=trinket1,if=!trinket.1.has_proc.any|buff.ca_inc.up|fight_remains<20
    -- use_items,slots=trinket2,if=!trinket.2.has_proc.any|buff.ca_inc.up|fight_remains<20
    -- use_items
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
    -- warrior_of_elune
    if S.WarriorofElune:IsCastable() then
      if HR.Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorofElune) then return "warrior_of_elune 108"; end
    end
    -- innervate,if=(cooldown.incarnation.remains<2|cooldown.celestial_alignment.remains<12)
    if S.Innervate:IsCastable() and Settings.Balance.ShowInnervate and ((S.Incarnation:CooldownRemains() < 2 or S.CelestialAlignment:CooldownRemains() < 12)) then
      if HR.Cast(S.Innervate) then return "innervate 110"; end
    end
    -- force_of_nature,if=(!buff.ca_inc.up|(buff.ca_inc.up|cooldown.ca_inc.remains>30))&ap_check
    if S.ForceofNature:IsCastable() and (Player:BuffDown(CaInc()) and (Player:BuffUp(CaInc()) or CaInc():CooldownRemains() > 30)) and AP_Check(S.ForceofNature) then
      if HR.Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceofNature, nil, 40) then return "force_of_nature 1111"; end
    end
    -- incarnation,if=!buff.ca_inc.up&(buff.memory_of_lucid_dreams.up|((cooldown.memory_of_lucid_dreams.remains>20|!essence.memory_of_lucid_dreams.major)&ap_check))&(buff.memory_of_lucid_dreams.up|ap_check),target_if=dot.sunfire.remains>8&dot.moonfire.remains>12&(dot.stellar_flare.remains>6|!talent.stellar_flare.enabled)
    if S.Incarnation:IsCastable() and (Player:BuffDown(CaInc()) and AP_Check(S.Incarnation)) or AP_Check(S.Incarnation) and (Target:DebuffRemains(S.SunfireDebuff) > 8 and Target:DebuffRemains(S.MoonfireDebuff) > 12 and (Target:DebuffRemains(S.StellarFlareDebuff) > 6 or not S.StellarFlare:IsAvailable())) then
      if HR.Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CelestialAlignment) then return "incarnation 228" end
    end
    -- celestial_alignment,if=!buff.ca_inc.up&(!talent.starlord.enabled|buff.starlord.up)&(buff.memory_of_lucid_dreams.up|((cooldown.memory_of_lucid_dreams.remains>20|!essence.memory_of_lucid_dreams.major)&ap_check))&(buff.lively_spirit.up),target_if=(dot.sunfire.remains>2&dot.moonfire.ticking&(dot.stellar_flare.ticking|!talent.stellar_flare.enabled))
    if S.CelestialAlignment:IsCastable() and (Player:BuffDown(CaInc()) and (not S.Starlord:IsAvailable() or Player:BuffUp(S.StarlordBuff)) and AP_Check(S.CelestialAlignment)) and (Player:BuffUp(S.LivelySpiritBuff)) 
	and (Target:DebuffRemains(S.SunfireDebuff) > 2 and Target:Debuff(S.MoonfireDebuff) and (Target:Debuff(S.StellarFlareDebuff) or not S.StellarFlare:IsAvailable())) then
      if HR.Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CelestialAlignment) then return "celestial_alignment 253" end
    end
    -- fury_of_elune,if=(buff.ca_inc.up|cooldown.ca_inc.remains>30)&solar_wrath.ap_check
    if S.FuryofElune:IsCastable() and ((Player:BuffUp(CaInc()) or CaInc():CooldownRemains() > 30) and AP_Check(S.SolarWrath)) then
      if HR.Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryofElune, nil, 40) then return "fury_of_elune 146"; end
    end
    -- cancel_buff,name=starlord,if=buff.starlord.remains<3&!solar_wrath.ap_check
    -- if (Player:BuffRemains(S.StarlordBuff) < 3 and not bool(solar_wrath.ap_check)) then
      -- if HR.Cancel(S.StarlordBuff) then return ""; end
    -- end
    -- starfall,if=(!solar_wrath.ap_check|(buff.starlord.stack<3|buff.starlord.remains>=8)&(fight_remains+1)*spell_targets>cost%2.5)&spell_targets>=variable.sf_targets
    if S.Starfall:IsReady() then
      local FightRemains = HL.FightRemains(EnemiesFourty, false)
      if ((not AP_Check(S.SolarWrath) or (Player:BuffStack(S.StarlordBuff) < 3 or Player:BuffRemains(S.StarlordBuff) >= 8) and (FightRemains + 1) * EnemiesCount > S.Starfall:Cost() % 2.5) and EnemiesCount >= VarSfTargets) then
        if HR.Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall) then return "starfall 164"; end
      end
    end
    -- starsurge,if=((talent.starlord.enabled&(buff.starlord.stack<3|buff.starlord.remains>=5&buff.arcanic_pulsar.stack<8)|!talent.starlord.enabled&(buff.arcanic_pulsar.stack<8|buff.ca_inc.up))&buff.solar_empowerment.stack<3&buff.lunar_empowerment.stack<3&buff.reckless_force_counter.stack<19|buff.reckless_force.up)&spell_targets.starfall<variable.sf_targets&(!buff.ca_inc.up|!prev.starsurge)|fight_remains<=execute_time*astral_power%40|!solar_wrath.ap_check
    if S.Starsurge:IsReady() and (((S.Starlord:IsAvailable() 
	and (Player:BuffStack(S.StarlordBuff) < 3 or Player:BuffRemains(S.StarlordBuff) >= 5 
	and Player:BuffStack(S.ArcanicPulsarBuff) < 8) or not S.Starlord:IsAvailable() 
	and (Player:BuffStack(S.ArcanicPulsarBuff) < 8 or Player:BuffUp(CaInc())))
	and Player:BuffStack(S.SolarEmpowermentBuff) < 3 and Player:BuffStack(S.LunarEmpowermentBuff) < 3 
	and Player:BuffStack(S.RecklessForceBuff) < 19 or Player:BuffDown(S.RecklessForceBuff)) and EnemiesCount < VarSfTargets 
	and (Player:BuffDown(CaInc()) 
	or not Player:PrevGCDP(1, S.Starsurge)) or HL.BossFilteredFightRemains("<", S.Starsurge:ExecuteTime() * Player:AstralPower() % 40) or not AP_Check(S.SolarWrath)) then
      if HR.Cast(S.Starsurge, nil, nil, 40) then return "starsurge 188"; end
    end
    -- sunfire,if=buff.ca_inc.up&buff.ca_inc.remains<gcd.max&dot.moonfire.remains>remains
    if S.Sunfire:IsCastable() and (Player:BuffUp(CaInc()) and Player:BuffRemains(CaInc()) < Player:GCD() and Target:DebuffRemains(S.MoonfireDebuff) > Target:DebuffRemains(S.SunfireDebuff)) then
      if HR.Cast(S.Sunfire, nil, nil, 40) then return "sunfire 222"; end
    end
    -- moonfire,if=buff.ca_inc.up&buff.ca_inc.remains<gcd.max
    if S.Moonfire:IsCastable() and (Player:BuffUp(CaInc()) and Player:BuffRemains(CaInc()) < Player:GCD()) then
      if HR.Cast(S.Moonfire) then return "moonfire 238"; end
    end
    -- sunfire,target_if=refreshable,if=ap_check&floor(target.time_to_die%(2*spell_haste))*spell_targets>=ceil(floor(2%spell_targets)*1.5)+2*spell_targets&(spell_targets>1+talent.twin_moons.enabled|dot.moonfire.ticking)&(buff.ca_inc.up|!prev.sunfire)&(buff.ca_inc.remains>remains|!buff.ca_inc.up)
    if S.Sunfire:IsCastable() then
      if Everyone.CastCycle(S.Sunfire, EnemiesFourty, EvaluateCycleSunfire250) then return "sunfire 308" end
    end
    -- moonfire,target_if=refreshable,if=ap_check&floor(target.time_to_die%(2*spell_haste))*spell_targets>=6&(!buff.ca_inc.up|!prev.moonfire)&(buff.ca_inc.remains>remains|!buff.ca_inc.up)
    if S.Moonfire:IsCastable() then
      if Everyone.CastCycle(S.Moonfire, EnemiesFourty, EvaluateCycleMoonfire313) then return "moonfire 343" end
    end
    -- stellar_flare,target_if=refreshable,if=ap_check&floor(target.time_to_die%(2*spell_haste))>=5&(!buff.ca_inc.up|!prev.stellar_flare)
    if S.StellarFlare:IsCastable() then
      if Everyone.CastCycle(S.StellarFlare, EnemiesFourty, EvaluateCycleStellarFlare348) then return "stellar_flare 360" end
    end
    -- new_moon,if=ap_check
    if S.NewMoon:IsCastable() and (AP_Check(S.NewMoon)) then
      if HR.Cast(S.NewMoon, nil, nil, 40) then return "new_moon 361"; end
    end
    -- half_moon,if=ap_check
    if S.HalfMoon:IsCastable() and (AP_Check(S.HalfMoon)) then
      if HR.Cast(S.HalfMoon, nil, nil, 40) then return "half_moon 363"; end
    end
    -- full_moon,if=ap_check
    if S.FullMoon:IsCastable() and (AP_Check(S.FullMoon)) then
      if HR.Cast(S.FullMoon, nil, nil, 40) then return "full_moon 365"; end
    end
    -- lunar_strike,if=buff.solar_empowerment.stack<3&(ap_check|buff.lunar_empowerment.stack=3)&((buff.warrior_of_elune.up|buff.lunar_empowerment.up|spell_targets>=2&!buff.solar_empowerment.up)&(!buff.ca_inc.up)|buff.ca_inc.up&prev.solar_wrath)
    if S.LunarStrike:IsCastable() and (Player:BuffStack(S.SolarEmpowermentBuff) < 3 and (AP_Check(S.LunarStrike) or Player:BuffStack(S.LunarEmpowermentBuff) == 3) and ((Player:BuffUp(S.WarriorofEluneBuff) or Player:BuffUp(S.LunarEmpowermentBuff) or EnemiesCount >= 2 and Player:BuffDown(S.SolarEmpowermentBuff)) and (Player:BuffDown(CaInc())) and Player:BuffUp(CaInc()) and Player:PrevGCDP(1, S.SolarWrath))) then
      if HR.Cast(S.LunarStrike, nil, nil, 40) then return "lunar_strike 367"; end
    end
    -- solar_wrath,if=!buff.ca_inc.up|!prev.solar_wrath
    if S.SolarWrath:IsCastable() and (Player:BuffDown(CaInc()) or not Player:PrevGCDP(1, S.SolarWrath)) then
      if HR.Cast(S.SolarWrath, nil, nil, 40) then return "solar_wrath 393"; end
    end
    -- sunfire
    if S.Sunfire:IsCastable() then
      if HR.Cast(S.Sunfire, nil, nil, 40) then return "sunfire 399"; end
    end
  end
end

local function Init()
--  HL.RegisterNucleusAbility(164815, 8, 6)               -- Sunfire DoT
--  HL.RegisterNucleusAbility(191037, 15, 6)              -- Starfall
--  HL.RegisterNucleusAbility(194153, 8, 6)               -- Lunar Strike
end

HR.SetAPL(102, APL, Init)
