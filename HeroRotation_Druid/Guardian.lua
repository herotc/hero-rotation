--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Pet = Unit.Pet
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local Cast  = HR.Cast
-- Lua

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Guardian = HR.GUISettings.APL.Druid.Guardian
}

-- Spells
local S = Spell.Druid.Guardian

-- Items
local I = Item.Druid.Guardian
local OnUseExcludes = {--  I.TrinketName:ID(),
}

-- Rotation Variables
local ActiveMitigationNeeded
local IsTanking
local UseMaul

-- Enemies Variables
local MeleeEnemies5y
local MeleeEnemies8y, MeleeEnemies8yCount

-- Legendaries
local LuffaInfusedEmbraceEquipped = Player:HasLegendaryEquipped(58)

-- Event Registrations
HL:RegisterForEvent(function()
  LuffaInfusedEmbraceEquipped = Player:HasLegendaryEquipped(58)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.AdaptiveSwarm:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.AdaptiveSwarm:RegisterInFlight()

-- num/bool Functions
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-- Functions
local function EvaluateCycleThrash(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.ThrashDebuff) or TargetUnit:DebuffStack(S.ThrashDebuff) < 3 or (TargetUnit:DebuffStack(S.ThrashDebuff) < 4 and LuffaInfusedEmbraceEquipped) or MeleeEnemies8yCount >= 4)
end

local function EvaluateCyclePulverize(TargetUnit)
  return (TargetUnit:DebuffStack(S.ThrashDebuff) > 2)
end

local function Defensives()
  if Player:HealthPercentage() < Settings.Guardian.FrenziedRegenHP and S.FrenziedRegeneration:IsReady() and Player:BuffDown(S.FrenziedRegenerationBuff) and not Player:HealingAbsorbed() then
    if Cast(S.FrenziedRegeneration, nil, Settings.Guardian.DisplayStyle.Defensives) then return "frenzied_regeneration defensive 2"; end
  end
  if S.Ironfur:IsCastable() and (Player:Rage() >= S.Ironfur:Cost() + 1 and IsTanking and (Player:BuffDown(S.IronfurBuff) or Player:BuffStack(S.IronfurBuff) < 2 and Player:BuffRefreshable(S.Ironfur))) then
    if Cast(S.Ironfur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "ironfur defensive 4"; end
  end
  if S.Barkskin:IsCastable() and (Player:HealthPercentage() < Settings.Guardian.BarkskinHP) then
    if Cast(S.Barkskin, nil, Settings.Guardian.DisplayStyle.Defensives) then return "barkskin defensive 6"; end
  end
  if S.SurvivalInstincts:IsCastable() and (Player:HealthPercentage() < Settings.Guardian.SurvivalInstinctsHP) then
    if Cast(S.SurvivalInstincts, nil, Settings.Guardian.DisplayStyle.Defensives) then return "survival_instincts defensive 8"; end
  end
  if S.BristlingFur:IsCastable() and (Player:Rage() < Settings.Guardian.BristlingFurRage) then
    if Cast(S.BristlingFur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "bristling_fur defensive 10"; end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- cat_form,if=(druid.catweave_bear)|(covenant.night_fae&talent.feral_affinity.enabled)
  -- prowl,if=druid.catweave_bear
  -- moonkin_form,if=(druid.owlweave_bear)|(covenant.night_fae&talent.balance_affinity.enabled)
  -- NOTE: Not handling cat-weaving or owl-weaving
  -- bear_form,if=((!druid.owlweave_bear&!druid.catweave_bear)&(!covenant.night_fae))|((!druid.owlweave_bear&!druid.catweave_bear)&(covenant.night_fae&talent.restoration_affinity.enabled))
  if S.BearForm:IsCastable() and (Player:BuffDown(S.BearForm)) then
    if Cast(S.BearForm) then return "bear_form precombat 2"; end
  end
  -- heart_of_the_Wild,if=talent.heart_of_the_wild.enabled&(druid.catweave_bear|druid.owlweave_bear|talent.balance_affinity.enabled)
  -- wrath,if=druid.owlweave_bear&!covenant.night_fae
  -- starfire,if=druid.owlweave_bear&covenant.night_fae
  -- NOTE: Not handling cat-weaving or owl-weaving
  -- Manually added: wild_charge
  if S.WildCharge:IsCastable() and (Target:IsInRange(25) and not Target:IsInRange(8)) then
    if Cast(S.WildCharge) then return "wild_charge precombat 4"; end
  end
  -- Manually added: mangle
  if S.Mangle:IsCastable() and Target:IsInMeleeRange(5) then
    if Cast(S.Mangle) then return "mangle precombat 6"; end
  end
  -- Manually added: thrash_bear
  if S.Thrash:IsCastable() and Target:IsInRange(8) then
    if Cast(S.Thrash) then reutrn "thrash precombat 8"; end
  end
  -- Manually added: moonfire
  if S.Moonfire:IsCastable() then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire precombat 10"; end
  end
end

local function LycaraOwl()
  -- moonkin_form
end

local function LycaraCat()
  -- cat_form
end

local function OwlConvoke()
  -- moonkin_form
  -- convoke_the_spirits
end

local function CatConvoke()
  -- cat_form
  -- convoke_the_spirits
end

local function Bear()
  -- bear_form,if=!buff.bear_form.up
  if S.BearForm:IsCastable() and (Player:BuffDown(S.BearForm)) then
    if Cast(S.BearForm) then return "bear_form bear 2"; end
  end
  -- ravenous_frenzy
  if S.RavenousFrenzy:IsCastable() then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant) then return "ravenous_frenzy bear 4"; end
  end
  -- convoke_the_spirits,if=!druid.catweave_bear&!druid.owlweave_bear
  if S.ConvoketheSpirits:IsCastable() then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInMeleeRange(5)) then return "convoke_the_spirits bear 6"; end
  end
  -- berserk_bear,if=(buff.ravenous_frenzy.up|!covenant.venthyr)
  if S.Berserk:IsCastable() and IsTanking and (Player:BuffUp(S.RavenousFrenzyBuff) or Player:Covenant() ~= "Venthyr") then
    if Cast(S.Berserk, Settings.Guardian.OffGCDasOffGCD.Berserk) then return "berserk bear 8"; end
  end
  -- incarnation,if=(buff.ravenous_frenzy.up|!covenant.venthyr)
  if S.Incarnation:IsCastable() and IsTanking and (Player:BuffUp(S.RavenousFrenzyBuff) or Player:Covenant() ~= "Venthyr") then
    if Cast(S.Incarnation, Settings.Guardian.OffGCDasOffGCD.Incarnation) then return "incarnation bear 10"; end
  end
  -- berserking,if=(buff.berserk_bear.up|buff.incarnation_guardian_of_ursoc.up)
  if S.Berserking:IsCastable() and (Player:BuffUp(S.BerserkBuff) or Player:BuffUp(S.IncarnationBuff)) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking bear 12"; end
  end
  -- empower_bond,if=(!druid.catweave_bear&!druid.owlweave_bear)|active_enemies>=2
  if S.EmpowerBond:IsCastable() then
    if Cast(S.EmpowerBond, nil, Settings.Commons.DisplayStyle.Covenant) then return "empower_bond bear 14"; end
  end
  -- barkskin,if=talent.brambles.enabled
  if S.Barkskin:IsCastable() and IsTanking then
    if Cast(S.Barkskin, nil, Settings.Guardian.DisplayStyle.Defensives) then return "barkskin bear 16"; end
  end
  -- adaptive_swarm,if=(!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>3)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<5&dot.adaptive_swarm_damage.ticking)
  if S.AdaptiveSwarm:IsCastable() and (Target:DebuffDown(S.AdaptiveSwarmDebuff) and not S.AdaptiveSwarm:InFlight() and (Target:DebuffDown(S.AdaptiveSwarmDebuff) or Player:BuffRemains(S.AdaptiveSwarmHeal) > 3) or Target:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and Target:DebuffRemains(S.AdaptiveSwarmDebuff) < 5 and Target:DebuffUp(S.AdaptiveSwarmDebuff)) then
    if Cast(S.AdaptiveSwarm, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm bear 18"; end
  end
  -- thrash_bear,target_if=refreshable|dot.thrash_bear.stack<3|(dot.thrash_bear.stack<4&runeforge.luffainfused_embrace.equipped)|active_enemies>=4
  if S.Thrash:IsCastable() then
    if Everyone.CastCycle(S.Thrash, MeleeEnemies8y, EvaluateCycleThrash, not Target:IsInMeleeRange(8)) then return "thrash bear 20"; end
  end
  -- moonfire,if=((buff.galactic_guardian.up)&active_enemies<2)|((buff.galactic_guardian.up)&!dot.moonfire.ticking&active_enemies>1&target.time_to_die>12)
  if S.Moonfire:IsCastable() and ((Player:BuffUp(S.GalacticGuardianBuff) and MeleeEnemies8yCount < 2) or (Player:BuffUp(S.GalacticGuardianBuff) and Target:DebuffDown(S.MoonfireDebuff) and MeleeEnemies8yCount > 1 and Target:TimeToDie() > 12)) then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 22"; end
  end
  -- moonfire,if=(dot.moonfire.remains<=3&(buff.galactic_guardian.up)&active_enemies>5&target.time_to_die>12)
  if S.Moonfire:IsCastable() and (Target:DebuffRemains(S.MoonfireDebuff) <= 3 and Player:BuffUp(S.GalacticGuardianBuff) and MeleeEnemies8yCount > 5 and Target:TimeToDie() > 12) then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 24"; end
  end
  -- moonfire,if=(refreshable&active_enemies<2&target.time_to_die>12)|(!dot.moonfire.ticking&active_enemies>1&target.time_to_die>12)
  if S.Moonfire:IsCastable() and ((Target:DebuffRefreshable(S.MoonfireDebuff) and MeleeEnemies8yCount < 2 and Target:TimeToDie() > 12) or (Target:DebuffDown(S.MoonfireDebuff) and MeleeEnemies8yCount > 1 and Target:TimeToDie() > 12)) then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 26"; end
  end
  -- swipe,if=buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&active_enemies>=4
  if S.Swipe:IsCastable() and (Player:BuffDown(S.IncarnationBuff) and Player:BuffDown(S.BerserkBuff) and MeleeEnemies8yCount >= 4) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bear 28"; end
  end
  -- maul,if=buff.incarnation.up&active_enemies<2
  if S.Maul:IsReady() and UseMaul and (Player:BuffUp(S.IncarnationBuff) and MeleeEnemies8yCount < 2) then
    if Cast(S.Maul, nil, nil, not Target:IsInMeleeRange(5)) then return "maul bear 30"; end
  end
  -- maul,if=(buff.savage_combatant.stack>=1)&(buff.tooth_and_claw.up)&buff.incarnation.up&active_enemies=2
  if S.Maul:IsReady() and UseMaul and (Player:BuffStack(S.SavageCombatantBuff) >= 1 and Player:BuffUp(S.ToothandClawBuff) and Player:BuffUp(S.IncarnationBuff) and MeleeEnemies8yCount == 2) then
    if Cast(S.Maul, nil, nil, not Target:IsInMeleeRange(5)) then return "maul bear 32"; end
  end
  -- mangle,if=buff.incarnation.up&active_enemies<=3
  if S.Mangle:IsCastable() and (Player:BuffUp(S.IncarnationBuff) and MeleeEnemies8yCount <= 3) then
    if Cast(S.Mangle, nil, nil, not Target:IsInMeleeRange(5)) then return "mangle bear 34"; end
  end
  -- maul,if=(((buff.tooth_and_claw.stack>=2)|(buff.tooth_and_claw.up&buff.tooth_and_claw.remains<1.5)|(buff.savage_combatant.stack>=3))&active_enemies<3)
  if S.Maul:IsReady() and UseMaul and ((Player:BuffStack(S.ToothandClawBuff) >= 2 or (Player:BuffUp(S.ToothandClawBuff) and Player:BuffRemains(S.ToothandClawBuff) < 1.5) or Player:BuffStack(S.SavageCombatantBuff) >= 3) and MeleeEnemies8yCount < 3) then
    if Cast(S.Maul, nil, nil, not Target:IsInMeleeRange(5)) then return "maul bear 36"; end
  end
  -- thrash_bear,if=active_enemies>1
  if S.Thrash:IsCastable() and (MeleeEnemies8yCount > 1) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bear 38"; end
  end
  -- mangle,if=((rage<90)&active_enemies<3)|((rage<85)&active_enemies<3&talent.soul_of_the_forest.enabled)
  if S.Mangle:IsCastable() and ((Player:Rage() < 90 and MeleeEnemies8yCount < 3) or (Player:Rage() < 85 and MeleeEnemies8yCount < 3 and S.SouloftheForest:IsAvailable())) then
    if Cast(S.Mangle, nil, nil, not Target:IsInMeleeRange(5)) then return "mangle bear 40"; end
  end
  -- pulverize,target_if=dot.thrash_bear.stack>2
  if S.Pulverize:IsReady() then
    if Everyone.CastCycle(S.Pulverize, MeleeEnemies8y, EvaluateCyclePulverize, not Target:IsInMeleeRange(5)) then return "pulverize bear 42"; end
  end
  -- thrash_bear
  if S.Thrash:IsCastable() then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bear 44"; end
  end
  -- maul,if=active_enemies<3
  if S.Maul:IsReady() and UseMaul and (MeleeEnemies8yCount < 3) then
    if Cast(S.Maul, nil, nil, not Target:IsInMeleeRange(5)) then return "maul bear 46"; end
  end
  -- swipe_bear
  if S.Swipe:IsCastable() then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bear 48"; end
  end
  -- ironfur,if=rage.deficit<40&buff.ironfur.remains<0.5
  -- Handled via Defensives()
end

local function CatWeave()
  -- cat_form,if=!buff.cat_form.up
  -- rake,if=buff.prowl.up
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&!buff.heart_of_the_wild.up
  -- empower_bond,if=druid.catweave_bear
  -- rake,if=dot.rake.refreshable&combo_points<4
  -- rip,if=dot.rip.refreshable&combo_points>=1
  -- convoke_the_spirits,if=druid.catweave_bear
  -- ferocious_bite,if=combo_points>=4&energy>50
  -- adaptive_swarm,if=(!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>3)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<5&dot.adaptive_swarm_damage.ticking)
  -- shred
end

local function OwlWeave()
  -- moonkin_form,if=!buff.moonkin_form.up
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&!buff.heart_of_the_wild.up
  -- starsurge
  -- convoke_the_spirits,if=soulbind.first_strike.enabled	
  -- empower_bond,if=druid.owlweave_bear
  -- adaptive_swarm,if=(!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>3)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<5&dot.adaptive_swarm_damage.ticking)
  -- sunfire,target_if=refreshable
  -- moonfire,target_if=refreshable|buff.galactic_guardian.up
  -- starfire,if=covenant.night_fae&eclipse.any_next
  -- wrath,if=!covenant.night_fae&eclipse.any_next
  -- convoke_the_spirits,if=(buff.eclipse_lunar.up|buff.eclipse_solar.up)
  -- starfire,if=(eclipse.in_lunar|eclipse.solar_next)|(eclipse.in_lunar&buff.starsurge_empowerment_lunar.up)
  -- wrath
end

local function APL()
  -- Enemies Update
  if AoEON() then
    MeleeEnemies8y = Player:GetEnemiesInMeleeRange(8)
    MeleeEnemies8yCount = #MeleeEnemies8y
    MeleeEnemies5y = Player:GetEnemiesInMeleeRange(5)
  else
    MeleeEnemies8y = {}
    MeleeEnemies5y = {}
    MeleeEnemies8yCount = 1
  end

  ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

  UseMaul = false
  if (not Settings.Guardian.UseRageDefensively or (Settings.Guardian.UseRageDefensively and (not IsTanking or Player:RageDeficit() <= 10))) then
    UseMaul = true
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupt
    local ShouldReturn = Everyone.Interrupt(13, S.SkullBash, Settings.Guardian.OffGCDasOffGCD.SkullBash, false); if ShouldReturn then return ShouldReturn; end
    -- Manually added: run_action_list,name=defensives
    if (IsTanking and Player:BuffUp(S.BearForm)) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack,if=!buff.prowl.up
    -- use_items,if=!buff.prowl.up
    if Settings.Commons.Enabled.Trinkets then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- potion,if=(((talent.heart_of_the_wild.enabled&buff.heart_of_the_wild.up)&(druid.catweave_bear|druid.owlweave_bear)&!buff.prowl.up)|((buff.berserk_bear.up|buff.incarnation_guardian_of_ursoc.up)&(!druid.catweave_bear&!druid.owlweave_bear)))
    if Settings.Commons.Enabled.Potions and I.PotionofSpectralAgility:IsReady() and (Player:BuffUp(S.BerserkBuff) or Player:BuffUp(S.Incarnation)) then
      if Cast(I.PotionofSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main"; end
    end
    -- run_action_list,name=catweave,if=druid.catweave_bear&((cooldown.thrash_bear.remains>0&cooldown.mangle.remains>0&dot.moonfire.remains>=gcd+0.5&rage<40&buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&buff.galactic_guardian.down)|(buff.cat_form.up&energy>25)|(dot.rake.refreshable&dot.rip.refreshable)|(runeforge.oath_of_the_elder_druid.equipped&!buff.oath_of_the_elder_druid.up&(buff.cat_form.up&energy>20)&buff.heart_of_the_wild.remains<=10)|(covenant.kyrian&cooldown.empower_bond.remains<=1&active_enemies<2)|(buff.heart_of_the_wild.up&energy>90))
    -- Skipping, as we're not handling cat-weaving
    -- run_action_list,name=owlweave,if=druid.owlweave_bear&((cooldown.thrash_bear.remains>0&cooldown.mangle.remains>0&rage<15&buff.incarnation.down&buff.berserk_bear.down&buff.galactic_guardian.down)|(buff.moonkin_form.up&dot.sunfire.refreshable)|(buff.moonkin_form.up&buff.heart_of_the_wild.up)|(runeforge.oath_of_the_elder_druid.equipped&!buff.oath_of_the_elder_druid.up)|(covenant.night_fae&cooldown.convoke_the_spirits.remains<=1)|(covenant.kyrian&cooldown.empower_bond.remains<=1&active_enemies<2))
    -- Skipping, as we're not handling owl-weaving
    -- run_action_list,name=lycarao,if=((runeforge.lycaras_fleeting_glimpse.equipped)&(talent.balance_affinity.enabled)&(buff.lycaras_fleeting_glimpse.up)&(buff.lycaras_fleeting_glimpse.remains<=2))
    -- Skipping, as we're not handling owl-weaving
    -- run_action_list,name=lycarac,if=((runeforge.lycaras_fleeting_glimpse.equipped)&(talent.feral_affinity.enabled)&(buff.lycaras_fleeting_glimpse.up)&(buff.lycaras_fleeting_glimpse.remains<=2))
    -- Skipping, as we're not handling cat-weaving
    -- run_action_list,name=oconvoke,if=((talent.balance_affinity.enabled)&(!druid.catweave_bear)&(!druid.owlweave_bear)&(covenant.night_fae&cooldown.convoke_the_spirits.remains<=1))
    -- Skipping, as we're not handling owl-weaving
    -- run_action_list,name=cconvoke,if=((talent.feral_affinity.enabled)&(!druid.catweave_bear)&(!druid.owlweave_bear)&(covenant.night_fae&cooldown.convoke_the_spirits.remains<=1))
    -- Skipping, as we're not handling cat-weaving
    -- run_action_list,name=bear
    if (true) then
      local ShouldReturn = Bear(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: Pool if nothing to do
    if (true) then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
    end
  end
end

local function OnInit()
end

HR.SetAPL(104, APL, OnInit)
