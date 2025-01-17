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
-- lua
local mathfloor     = math.floor
-- WoW API
local Delay       = C_Timer.After

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Druid.Guardian
local I = Item.Druid.Guardian

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.Item:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  CommonsDS = HR.GUISettings.APL.Druid.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Druid.CommonsOGCD,
  Guardian = HR.GUISettings.APL.Druid.Guardian
}

--- ===== Rotation Variables =====
local VarIFBuild = S.ThornsofIron:IsAvailable() and S.ReinforcedFur:IsAvailable()
local VarRipWeaving = S.PrimalFury:IsAvailable() and S.FluidForm:IsAvailable() and S.WildpowerSurge:IsAvailable()
local MeleeRange, AoERange
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local UseMaul
local Enemies8y, Enemies8yCount

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1Range, VarTrinket2Range
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1Range = T1.Range
  VarTrinket2Range = T2.Range
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarIFBuild = S.ThornsofIron:IsAvailable() and S.ReinforcedFur:IsAvailable()
  VarRipWeaving = S.PrimalFury:IsAvailable() and S.FluidForm:IsAvailable() and S.WildpowerSurge:IsAvailable()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== CastCycle Functions =====
local function EvaluateCycleMoonfire(TargetUnit)
  -- if=buff.bear_form.up&(((!ticking&target.time_to_die>12)|(refreshable&target.time_to_die>12))&active_enemies<7&talent.fury_of_nature.enabled)|(((!ticking&target.time_to_die>12)|(refreshable&target.time_to_die>12))&active_enemies<4&!talent.fury_of_nature.enabled)
  -- Note: Simplified.
  return ((TargetUnit:DebuffDown(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 12) or (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 12)) and (Enemies8yCount < 7 and S.FuryofNature:IsAvailable() or Enemies8yCount < 4 and not S.FuryofNature:IsAvailable())
end

local function EvaluateCyclePulverize(TargetUnit)
  -- target_if=dot.thrash_bear.stack>2
  return TargetUnit:DebuffStack(S.ThrashBearDebuff) > 2
end

local function EvaluateCycleThrash(TargetUnit)
  -- target_if=refreshable|(dot.thrash_bear.stack<5&talent.flashing_claws.rank=2|dot.thrash_bear.stack<4&talent.flashing_claws.rank=1|dot.thrash_bear.stack<3&!talent.flashing_claws.enabled)
  return TargetUnit:DebuffRefreshable(S.ThrashBearDebuff) or (Target:DebuffStack(S.ThrashBearDebuff) < 5 and S.FlashingClaws:TalentRank() == 2 or TargetUnit:DebuffStack(S.ThrashBearDebuff) < 4 and S.FlashingClaws:TalentRank() == 1 or Target:DebuffStack(S.ThrashBearDebuff) < 3 and not S.FlashingClaws:IsAvailable())
end

--- ===== Rotation Functions =====
local function Precombat()
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and Everyone.GroupBuffMissing(S.MarkoftheWildBuff) then
    if Cast(S.MarkoftheWild, Settings.CommonsOGCD.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat 2"; end
  end
  -- variable,name=If_build,value=1,value_else=0,if=talent.thorns_of_iron.enabled&talent.reinforced_fur.enabled
  -- variable,name=ripweaving,value=1,value_else=0,if=talent.primal_fury.enabled&talent.fluid_form.enabled&talent.wildpower_surge.enabled
  -- Note: Handled in variable declarations and SPELLS_CHANGED/LEARNED_SPELL_IN_TAB.
  -- heart_of_the_Wild,if=talent.heart_of_the_wild.enabled&!talent.rip.enabled
  -- bear_form
  if S.BearForm:IsCastable() then
    if Cast(S.BearForm) then return "bear_form precombat 4"; end
  end
  -- Manually added: moonfire
  if S.Moonfire:IsCastable() then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire precombat 8"; end
  end
  -- Manually added: wild_charge
  if S.WildCharge:IsCastable() and (Target:IsInRange(S.WildCharge.MaximumRange) and not Target:IsInRange(S.WildCharge.MinimumRange)) then
    if Cast(S.WildCharge) then return "wild_charge precombat 10"; end
  end
  -- Manually added: thrash_bear
  if S.ThrashBear:IsCastable() and IsInAoERange then
    if Cast(S.ThrashBear) then return "thrash precombat 12"; end
  end
  -- Manually added: mangle
  if S.Mangle:IsCastable() and IsInMeleeRange then
    if Cast(S.Mangle) then return "mangle precombat 14"; end
  end
end

local function Defensives()
  if Player:HealthPercentage() < Settings.Guardian.FrenziedRegenHP and S.FrenziedRegeneration:IsReady() and Player:BuffDown(S.FrenziedRegenerationBuff) and not Player:HealingAbsorbed() then
    if Cast(S.FrenziedRegeneration, nil, Settings.Guardian.DisplayStyle.Defensives) then return "frenzied_regeneration defensive 2"; end
  end
  if S.Regrowth:IsCastable() and Player:BuffUp(S.DreamofCenariusBuff) and (Player:BuffDown(S.PoPHealBuff) and Player:HealthPercentage() < Settings.Guardian.DoCRegrowthNoPoPHP or Player:BuffUp(S.PoPHealBuff) and Player:HealthPercentage() < Settings.Guardian.DoCRegrowthWithPoPHP) then
    if Cast(S.Regrowth, nil, Settings.Guardian.DisplayStyle.Defensives) then return "regrowth defensive 4"; end
  end
  if S.Renewal:IsCastable() and Player:HealthPercentage() < Settings.Guardian.RenewalHP then
    if Cast(S.Renewal, nil, Settings.Guardian.DisplayStyle.Defensives) then return "renewal defensive 6"; end
  end
  if S.Ironfur:IsReady() and (Player:BuffDown(S.IronfurBuff) or Player:BuffStack(S.IronfurBuff) < 2 and Player:BuffRefreshable(S.Ironfur)) then
    if Cast(S.Ironfur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "ironfur defensive 8"; end
  end
  if S.Barkskin:IsCastable() and (Player:HealthPercentage() < Settings.Guardian.BarkskinHP and Player:BuffDown(S.IronfurBuff) or Player:HealthPercentage() < Settings.Guardian.BarkskinHP * 0.75) then
    if Cast(S.Barkskin, nil, Settings.Guardian.DisplayStyle.Defensives) then return "barkskin defensive 10"; end
  end
  if S.SurvivalInstincts:IsCastable() and (Player:HealthPercentage() < Settings.Guardian.SurvivalInstinctsHP) then
    if Cast(S.SurvivalInstincts, nil, Settings.Guardian.DisplayStyle.Defensives) then return "survival_instincts defensive 12"; end
  end
  if S.BristlingFur:IsCastable() and (Player:Rage() < Settings.Guardian.BristlingFurRage and S.RageoftheSleeper:CooldownRemains() > 8) then
    if Cast(S.BristlingFur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "bristling_fur defensive 14"; end
  end
end

local function Bear()
  -- maul,if=buff.ravage.up&active_enemies>1
  if S.RavageAbilityBear:IsReady() and (Player:BuffUp(S.RavageBuffGuardian) and Enemies8yCount > 1) then
      if Cast(S.RavageAbilityBear, nil, nil, not IsInMeleeRange) then return "ravage bear 2"; end
    end
  -- heart_of_the_Wild,if=(talent.heart_of_the_wild.enabled&!talent.rip.enabled)|talent.heart_of_the_wild.enabled&buff.feline_potential_counter.stack=6&active_enemies<3
  if CDsON() and S.HeartoftheWild:IsCastable() and (not S.Rip:IsAvailable() or Player:BuffStack(S.FelinePotentialBuff) == 6 and Enemies8yCount < 3) then
    if Cast(S.HeartoftheWild, Settings.Guardian.GCDasOffGCD.HeartOfTheWild) then return "heart_of_the_wild bear 4"; end
  end
  -- moonfire,cycle_targets=1,if=buff.bear_form.up&(((!ticking&target.time_to_die>12)|(refreshable&target.time_to_die>12))&active_enemies<7&talent.fury_of_nature.enabled)|(((!ticking&target.time_to_die>12)|(refreshable&target.time_to_die>12))&active_enemies<4&!talent.fury_of_nature.enabled)
  if S.Moonfire:IsCastable() and Player:BuffUp(S.BearForm) then
    if Everyone.CastCycle(S.Moonfire, Enemies8y, EvaluateCycleMoonfire, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 6"; end
  end
  -- thrash_bear,target_if=refreshable|(dot.thrash_bear.stack<5&talent.flashing_claws.rank=2|dot.thrash_bear.stack<4&talent.flashing_claws.rank=1|dot.thrash_bear.stack<3&!talent.flashing_claws.enabled)
  if S.ThrashBear:IsCastable() then
    if Everyone.CastCycle(S.ThrashBear, Enemies8y, EvaluateCycleThrash, not IsInAoERange) then return "thrash bear 8"; end
  end
  -- bristling_fur,if=!cooldown.pause_action.remains&cooldown.rage_of_the_sleeper.remains>8
  -- Note: Handled in Defensives().
  -- barkskin,if=buff.bear_form.up
  -- Note: Handled in Defensives().
  -- lunar_beam
  if CDsON() and S.LunarBeam:IsReady() then
      if Cast(S.LunarBeam, Settings.Guardian.GCDasOffGCD.LunarBeam) then return "lunar_beam bear 10"; end
    end
  -- convoke_the_spirits,if=(talent.wildpower_surge.enabled&buff.cat_form.up&buff.feline_potential.up)|!talent.wildpower_surge.enabled
  if CDsON() and S.ConvoketheSpirits:IsCastable() then
    if Cast(S.ConvoketheSpirits, nil, Settings.CommonsDS.DisplayStyle.ConvokeTheSpirits) then return "convoke_the_spirits bear 12"; end
  end
  -- berserk_bear
  if CDsON() and S.Berserk:IsCastable() then
    if Cast(S.Berserk, Settings.Guardian.OffGCDasOffGCD.Berserk) then return "berserk bear 14"; end
  end
  -- incarnation
  if CDsON() and S.Incarnation:IsCastable() then
    if Cast(S.Incarnation, Settings.Guardian.OffGCDasOffGCD.Incarnation) then return "incarnation bear 16"; end
  end
  -- rage_of_the_sleeper,if=(((buff.incarnation_guardian_of_ursoc.down&cooldown.incarnation_guardian_of_ursoc.remains>60)|buff.berserk_bear.down)&rage>40&(!talent.convoke_the_spirits.enabled)|(buff.incarnation_guardian_of_ursoc.up|buff.berserk_bear.up)&rage>40&(!talent.convoke_the_spirits.enabled)|(talent.convoke_the_spirits.enabled)&rage>40)
  if CDsON() and S.RageoftheSleeper:IsCastable() and (((Player:BuffDown(S.Incarnation) and S.Incarnation:CooldownRemains() > 60) or Player:BuffDown(S.Berserk)) and Player:Rage() > 40 and not S.ConvoketheSpirits:IsAvailable() or (Player:BuffUp(S.Incarnation) or Player:BuffUp(S.Berserk)) and Player:Rage() > 40 and not S.ConvoketheSpirits:IsAvailable() or S.ConvoketheSpirits:IsAvailable() and Player:Rage() > 40) then
    if Cast(S.RageoftheSleeper, Settings.Guardian.GCDasOffGCD.RageOfTheSleeper) then return "rage_of_the_sleeper bear 18"; end
  end
  -- berserking,if=(buff.berserk_bear.up|buff.incarnation_guardian_of_ursoc.up)
  if CDsON() and S.Berserking:IsCastable() and (Player:BuffUp(S.Berserk) or Player:BuffUp(S.Incarnation)) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking bear 20"; end
  end
  -- maul,if=buff.ravage.up&active_enemies<2
  if S.RavageAbilityBear:IsReady() and (Player:BuffUp(S.RavageBuffGuardian) and Enemies8yCount < 2) then
    if Cast(S.RavageAbilityBear, nil, nil, not IsInMeleeRange) then return "ravage bear 22"; end
  end
  -- raze,if=(buff.tooth_and_claw.stack>1|buff.tooth_and_claw.remains<1+gcd)&variable.If_build=1&active_enemies>1
  if S.Raze:IsReady() and ((Player:BuffStack(S.ToothandClawBuff) > 1 or Player:BuffRemains(S.ToothandClawBuff) < 1 + Player:GCD()) and VarIFBuild and Enemies8yCount > 1) then
    if Cast(S.Raze, nil, nil, not IsInMeleeRange) then return "raze bear 24"; end
  end
  -- thrash_bear,if=active_enemies>=5&talent.lunar_calling.enabled
  if S.ThrashBear:IsCastable() and (Enemies8yCount >= 5 and S.LunarCalling:IsAvailable()) then
    if Cast(S.ThrashBear, nil, nil, not IsInAoERange) then return "thrash bear 26"; end
  end
  -- ironfur,target_if=!debuff.tooth_and_claw.up,if=!buff.ironfur.up&rage>50&!cooldown.pause_action.remains&variable.If_build=0&!buff.rage_of_the_sleeper.up|rage>90&variable.If_build=0|!debuff.tooth_and_claw.up&!buff.ironfur.up&rage>50&!cooldown.pause_action.remains&variable.If_build=0&!buff.rage_of_the_sleeper.up
  if S.Ironfur:IsReady() and (Player:BuffDown(S.IronfurBuff) and Player:Rage() > 50 and IsTanking and not VarIFBuild and Player:BuffDown(S.RageoftheSleeper) or Player:Rage() > 90 and not VarIFBuild or Player:BuffDown(S.ToothandClawBuff) and Player:BuffDown(S.IronfurBuff) and Player:Rage() > 50 and IsTanking and not VarIFBuild and Player:BuffDown(S.RageoftheSleeper)) then
    if Cast(S.Ironfur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "ironfur bear 28"; end
  end
  -- ironfur,if=!buff.ravage.up&((rage>40&variable.If_build=1&cooldown.rage_of_the_sleeper.remains>3&talent.rage_of_the_sleeper.enabled|(buff.incarnation.up|buff.berserk_bear.up)&rage>20&variable.If_build=1&cooldown.rage_of_the_sleeper.remains>3&talent.rage_of_the_sleeper.enabled|rage>90&variable.If_build=1&!talent.fount_of_strength.enabled|rage>110&variable.If_build=1&talent.fount_of_strength.enabled|(buff.incarnation.up|buff.berserk_bear.up)&rage>20&variable.If_build=1&buff.rage_of_the_sleeper.up&talent.rage_of_the_sleeper.enabled))
  if S.Ironfur:IsReady() and (Player:BuffDown(S.RavageBuffGuardian) and (Player:Rage() > 40 and VarIFBuild and S.RageoftheSleeper:CooldownRemains() > 3 and S.RageoftheSleeper:IsAvailable() or (Player:BuffUp(S.Incarnation) or Player:BuffUp(S.Berserk)) and Player:Rage() > 20 and VarIFBuild and S.RageoftheSleeper:CooldownRemains() > 3 and S.RageoftheSleeper:IsAvailable() or Player:Rage() > 90 and VarIFBuild and not S.FountofStrength:IsAvailable() or Player:Rage() > 110 and VarIFBuild and S.FountofStrength:IsAvailable() or (Player:BuffUp(S.Incarnation) or Player:BuffUp(S.Berserk)) and Player:Rage() > 20 and VarIFBuild and Player:BuffUp(S.RageoftheSleeper) and S.RageoftheSleeper:IsAvailable())) then
    if Cast(S.Ironfur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "ironfur bear 30"; end
  end
  -- ironfur,if=!buff.ravage.up&((rage>40&variable.If_build=1&!talent.rage_of_the_sleeper.enabled|(buff.incarnation.up|buff.berserk_bear.up)&rage>20&variable.If_build=1&!talent.rage_of_the_sleeper.enabled|(buff.incarnation.up|buff.berserk_bear.up)&rage>20&variable.If_build=1&!talent.rage_of_the_sleeper.enabled))
  if S.Ironfur:IsReady() and (Player:BuffDown(S.RavageBuffGuardian) and (Player:Rage() > 40 and VarIFBuild and not S.RageoftheSleeper:IsAvailable() or (Player:BuffUp(S.Incarnation) or Player:BuffUp(S.Berserk)) and Player:Rage() > 20 and VarIFBuild and not S.RageoftheSleeper:IsAvailable() or (Player:BuffUp(S.Incarnation) or Player:BuffUp(S.Berserk)) and Player:Rage() > 20 and VarIFBuild and not S.RageoftheSleeper:IsAvailable())) then
    if Cast(S.Ironfur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "ironfur bear 32"; end
  end
  -- ferocious_bite,if=(buff.cat_form.up&buff.feline_potential.up&active_enemies<3&(buff.incarnation.up|buff.berserk_bear.up)&!dot.rip.refreshable)
  if S.FerociousBite:IsReady() and (Player:BuffUp(S.CatForm) and Player:BuffStack(S.FelinePotentialBuff) == 6 and Enemies8yCount < 3 and (Player:BuffUp(S.Incarnation) or Player:BuffUp(S.Berserk)) and not Target:DebuffRefreshable(S.RipDebuff)) then
    if Cast(S.FerociousBite, nil, nil, not IsInMeleeRange) then return "ferocious_bite bear 34"; end
  end
  -- rip,if=(buff.cat_form.up&buff.feline_potential.up&active_enemies<3&(!buff.incarnation.up|!buff.berserk_bear.up))|(buff.cat_form.up&buff.feline_potential.up&active_enemies<3&(buff.incarnation.up|buff.berserk_bear.up)&refreshable)
  if S.Rip:IsReady() and ((Player:BuffUp(S.CatForm) and Player:BuffStack(S.FelinePotentialBuff) == 6 and Enemies8yCount < 3 and (Player:BuffDown(S.Incarnation) or Player:BuffDown(S.Berserk))) or (Player:BuffUp(S.CatForm) and Player:BuffStack(S.FelinePotentialBuff) == 6 and Enemies8yCount < 3 and (Player:BuffUp(S.Incarnation) or Player:BuffUp(S.Berserk)) and Target:DebuffRefreshable(S.RipDebuff))) then
    if Cast(S.Rip, nil, nil, not IsInMeleeRange) then return "rip bear 36"; end
  end
  -- raze,if=variable.If_build=1&buff.vicious_cycle_maul.stack=3&active_enemies>1&!talent.ravage.enabled
  if S.Raze:IsReady() and (VarIFBuild and Player:BuffStack(S.ViciousCycleMaulBuff) == 3 and Enemies8yCount > 1 and not S.Ravage:IsAvailable()) then
    if Cast(S.Raze, nil, nil, not IsInMeleeRange) then return "raze bear 38"; end
  end
  -- mangle,if=buff.gore.up&active_enemies<11|buff.incarnation_guardian_of_ursoc.up&buff.feline_potential_counter.stack<6&talent.wildpower_surge.enabled
  if S.Mangle:IsCastable() and (Player:BuffUp(S.GoreBuff) and Enemies8yCount < 11 or Player:BuffUp(S.Incarnation) and Player:BuffStack(S.FelinePotentialBuff) < 6 and S.WildpowerSurge:IsAvailable()) then
    if Cast(S.Mangle, nil, nil, not IsInMeleeRange) then return "mangle bear 40"; end
  end
  -- raze,if=variable.If_build=0&(active_enemies>1|(buff.tooth_and_claw.up)&active_enemies>1|buff.vicious_cycle_maul.stack=3&active_enemies>1)
  if S.Raze:IsReady() and (not VarIFBuild and (Enemies8yCount > 1 or Player:BuffUp(S.ToothandClawBuff) and Enemies8yCount > 1 or Player:BuffStack(S.ViciousCycleMaulBuff) == 3 and Enemies8yCount > 1)) then
    if Cast(S.Raze, nil, nil, not IsInMeleeRange) then return "raze bear 42"; end
  end
  -- shred,if=cooldown.rage_of_the_sleeper.remains<=52&buff.feline_potential_counter.stack=6&!buff.cat_form.up&!dot.rake.refreshable&active_enemies<3&talent.fluid_form.enabled
  if S.Shred:IsReady() and (S.RageoftheSleeper:CooldownRemains() <= 52 and Player:BuffStack(S.FelinePotentialBuff) == 6 and Player:BuffDown(S.CatForm) and not Target:DebuffRefreshable(S.RakeDebuff) and Enemies8yCount < 3 and S.FluidForm:IsAvailable()) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred bear 44"; end
  end
  -- rake,if=cooldown.rage_of_the_sleeper.remains<=52&buff.feline_potential_counter.stack=6&!buff.cat_form.up&active_enemies<3&talent.fluid_form.enabled
  if S.Rake:IsReady() and (S.RageoftheSleeper:CooldownRemains() <= 52 and Player:BuffStack(S.FelinePotentialBuff) == 6 and Player:BuffDown(S.CatForm) and Enemies8yCount < 3 and S.FluidForm:IsAvailable()) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake bear 46"; end
  end
  -- mangle,if=buff.cat_form.up&talent.fluid_form.enabled
  if S.Mangle:IsCastable() and (Player:BuffUp(S.CatForm) and S.FluidForm:IsAvailable()) then
    if Cast(S.Mangle, nil, nil, not IsInMeleeRange) then return "mangle bear 48"; end
  end
  -- maul,if=variable.If_build=1&(((buff.tooth_and_claw.stack>1|buff.tooth_and_claw.remains<1+gcd)&active_enemies<=5&!talent.raze.enabled)|((buff.tooth_and_claw.stack>1|buff.tooth_and_claw.remains<1+gcd)&active_enemies=1&talent.raze.enabled)|((buff.tooth_and_claw.stack>1|buff.tooth_and_claw.remains<1+gcd)&active_enemies<=5&!talent.raze.enabled))
  if S.Maul:IsReady() and UseMaul and (VarIFBuild and (((Player:BuffStack(S.ToothandClawBuff) > 1 or Player:BuffRemains(S.ToothandClawBuff) < 1 + Player:GCD()) and Enemies8yCount <= 5 and not S.Raze:IsAvailable()) or ((Player:BuffStack(S.ToothandClawBuff) > 1 or Player:BuffRemains(S.ToothandClawBuff) < 1 + Player:GCD()) and Enemies8yCount == 1 and S.Raze:IsAvailable()) or ((Player:BuffStack(S.ToothandClawBuff) > 1 or Player:BuffRemains(S.ToothandClawBuff) < 1 + Player:GCD()) and Enemies8yCount <= 5 and not S.Raze:IsAvailable()))) then
    if Cast(S.Maul, nil, nil, not IsInMeleeRange) then return "maul bear 50"; end
  end
  -- maul,if=variable.If_build=0&((buff.tooth_and_claw.up&active_enemies<=5&!talent.raze.enabled)|(buff.tooth_and_claw.up&active_enemies=1&talent.raze.enabled))
  if S.Maul:IsReady() and UseMaul and (not VarIFBuild and ((Player:BuffUp(S.ToothandClawBuff) and Enemies8yCount <= 5 and not S.Raze:IsAvailable()) or (Player:BuffUp(S.ToothandClawBuff) and Enemies8yCount == 1 and S.Raze:IsAvailable()))) then
    if Cast(S.Maul, nil, nil, not IsInMeleeRange) then return "maul bear 52"; end
  end
  -- maul,if=(active_enemies<=5&!talent.raze.enabled&variable.If_build=0)|(active_enemies=1&talent.raze.enabled&variable.If_build=0)|buff.vicious_cycle_maul.stack=3&active_enemies<=5&!talent.raze.enabled
  if S.Maul:IsReady() and UseMaul and ((Enemies8yCount <= 5 and not S.Raze:IsAvailable() and not VarIFBuild) or (Enemies8yCount == 1 and S.Raze:IsAvailable() and not VarIFBuild) or Player:BuffStack(S.ViciousCycleMaulBuff) == 3 and Enemies8yCount <= 5 and not S.Raze:IsAvailable()) then
    if Cast(S.Maul, nil, nil, not IsInMeleeRange) then return "maul bear 54"; end
  end
  -- thrash_bear,if=active_enemies>=5
  if S.ThrashBear:IsCastable() and (Enemies8yCount >= 5) then
    if Cast(S.ThrashBear, nil, nil, not IsInAoERange) then return "thrash bear 56"; end
  end
  -- mangle,if=(buff.incarnation.up&active_enemies<=4)|(buff.incarnation.up&talent.soul_of_the_forest.enabled&active_enemies<=5)|((rage<88)&active_enemies<11)|((rage<83)&active_enemies<11&talent.soul_of_the_forest.enabled)
  if S.Mangle:IsCastable() and ((Player:BuffUp(S.Incarnation) and Enemies8yCount <= 4) or (Player:BuffUp(S.Incarnation) and S.SouloftheForest:IsAvailable() and Enemies8yCount <= 5) and ((Player:Rage() < 88) and Enemies8yCount < 11) or ((Player:Rage() < 83) and Enemies8yCount < 11 and S.SouloftheForest:IsAvailable())) then
    if Cast(S.Mangle, nil, nil, not IsInMeleeRange) then return "mangle bear 58"; end
  end
  -- thrash_bear,if=active_enemies>1
  if S.ThrashBear:IsCastable() and (Enemies8yCount > 1) then
    if Cast(S.ThrashBear, nil, nil, not IsInAoERange) then return "thrash bear 60"; end
  end
  -- pulverize,target_if=dot.thrash_bear.stack>2
  if S.Pulverize:IsReady() then
    if Everyone.CastCycle(S.Pulverize, Enemies8y, EvaluateCyclePulverize, not IsInMeleeRange) then return "pulverize bear 62"; end
  end
  -- thrash_bear
  if S.ThrashBear:IsCastable() then
    if Cast(S.ThrashBear, nil, nil, not IsInAoERange) then return "thrash bear 64"; end
  end
  -- moonfire,if=buff.galactic_guardian.up&buff.bear_form.up&talent.boundless_moonlight.enabled
  if S.Moonfire:IsCastable() and (Player:BuffUp(S.GalacticGuardianBuff) and Player:BuffUp(S.BearForm) and S.BoundlessMoonlight:IsAvailable()) then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 66"; end
  end
  -- rake,if=cooldown.rage_of_the_sleeper.remains<=52&rage<40&active_enemies<3&!talent.lunar_insight.enabled&talent.fluid_form.enabled&energy>70&refreshable&variable.ripweaving=1
  if S.Rake:IsReady() and (S.RageoftheSleeper:CooldownRemains() <= 52 and Player:Rage() < 40 and Enemies8yCount < 3 and not S.LunarInsight:IsAvailable() and S.FluidForm:IsAvailable() and Player:Energy() > 70 and Target:DebuffRefreshable(S.RakeDebuff) and VarRipWeaving) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake bear 68"; end
  end
  -- shred,if=cooldown.rage_of_the_sleeper.remains<=52&rage<40&active_enemies<3&!talent.lunar_insight.enabled&talent.fluid_form.enabled&energy>70&!buff.rage_of_the_sleeper.up&variable.ripweaving=1
  if S.Shred:IsReady() and (S.RageoftheSleeper:CooldownRemains() <= 52 and Player:Rage() < 40 and Enemies8yCount < 3 and not S.LunarInsight:IsAvailable() and S.FluidForm:IsAvailable() and Player:Energy() > 70 and Player:BuffDown(S.RageoftheSleeper) and VarRipWeaving) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred bear 70"; end
  end
  -- rip,if=buff.cat_form.up&!dot.rip.ticking&active_enemies<3&variable.ripweaving=1
  if S.Rip:IsReady() and (Player:BuffUp(S.CatForm) and Target:DebuffDown(S.RipDebuff) and Enemies8yCount < 3 and VarRipWeaving) then
    if Cast(S.Rip, nil, nil, not IsInMeleeRange) then return "rip bear 72"; end
  end
  -- ferocious_bite,if=dot.rip.ticking&combo_points>4&active_enemies<3&variable.ripweaving=1
  if S.FerociousBite:IsReady() and (Target:DebuffUp(S.RipDebuff) and Player:ComboPoints() > 4 and Enemies8yCount < 3 and VarRipWeaving) then
    if Cast(S.FerociousBite, nil, nil, not IsInMeleeRange) then return "ferocious_bite bear 74"; end
  end
  -- starsurge,if=talent.starsurge.enabled&rage<20
  if S.Starsurge:IsReady() and (Player:Rage() < 20) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge bear 76"; end
  end
  -- swipe_bear,if=(talent.lunar_insight.enabled&active_enemies>4)|!talent.lunar_insight.enabled|talent.lunar_insight.enabled&active_enemies<2
  if S.Swipe:IsCastable() and ((S.LunarInsight:IsAvailable() and Enemies8yCount > 4) or not S.LunarInsight:IsAvailable() or S.LunarInsight:IsAvailable() and Enemies8yCount < 2) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe bear 78"; end
  end
  -- moonfire,if=(talent.lunar_insight.enabled&active_enemies>1)&buff.bear_form.up
  if S.Moonfire:IsCastable() and ((S.LunarInsight:IsAvailable() and Enemies8yCount > 1) and Player:BuffUp(S.BearForm)) then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 80"; end
  end
end

local function APL()
  -- Enemies Update
  Enemies8y = Player:GetEnemiesInMeleeRange(8)
  if AoEON() then
    Enemies8yCount = #Enemies8y
  else
    Enemies8yCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
    IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

    UseMaul = false
    if ((Player:Rage() >= S.Maul:Cost() + 20 and not IsTanking) or Player:RageDeficit() <= 10 or not Settings.Guardian.UseRageDefensively) then
      UseMaul = true
    end

    IsInMeleeRange = Target:IsInRange(5)
    IsInAoERange = Target:IsInRange(8)
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupt
    local ShouldReturn = Everyone.Interrupt(S.SkullBash, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: run_action_list,name=defensives
    if (IsTanking and Player:BuffUp(S.BearForm)) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: wild_charge if not in range
    if S.WildCharge:IsCastable() and not Target:IsInRange(8) then
      if Cast(S.WildCharge, Settings.CommonsOGCD.GCDasOffGCD.WildCharge, nil, not Target:IsInRange(S.WildCharge.MaximumRange)) then return "wild_charge main 2"; end
    end
    -- auto_attack,if=!buff.prowl.up
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,slot=trinket1
      if Trinket1:IsReady() then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item trinket1 ("..tostring(Trinket1:Name())..") main 4"; end
      end
      -- use_item,slot=trinket2
      if Trinket2:IsReady() then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item trinket2 ("..tostring(Trinket2:Name())..") main 6"; end
      end
    end
    -- Manually added: use_items for non-trinkets
    if Settings.Commons.Enabled.Items then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
      if ItemToUse then
        if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " main 8"; end
      end
    end
    -- potion,if=(buff.berserk_bear.up|buff.incarnation_guardian_of_ursoc.up)
    if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.Berserk) or Player:BuffUp(S.Incarnation)) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 10"; end
      end
    end
    -- run_action_list,name=bear
    local ShouldReturn = Bear(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool Resources"; end
  end
end

local function OnInit()
  HR.Print("Guardian Druid rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(104, APL, OnInit)
