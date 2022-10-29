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

-- Rotation Variables
local ActiveMitigationNeeded
local IsTanking
local UseMaul

-- Enemies Variables
local MeleeEnemies5y
local MeleeEnemies8y, MeleeEnemies8yCount

-- Legendaries
local LuffaInfusedEmbraceEquipped = Player:HasLegendaryEquipped(58)

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- Event Registrations
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
local function EvaluateCycleMoonfire(TargetUnit)
  return ((TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 12) and MeleeEnemies8yCount < 6)
end

local function EvaluateCycleThrash(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.ThrashDebuff) or TargetUnit:DebuffStack(S.ThrashDebuff) < 3 or (TargetUnit:DebuffStack(S.ThrashDebuff) < 4 and LuffaInfusedEmbraceEquipped) or MeleeEnemies8yCount >= 4 or Player:BuffUp(S.BerserkBuff) and Player:BuffRemains(S.BerserkBuff) <= Player:GCD() + 0.5)
end

local function EvaluateCyclePulverize(TargetUnit)
  return (TargetUnit:DebuffStack(S.ThrashDebuff) > 2)
end

local function Defensives()
  if Player:HealthPercentage() < Settings.Guardian.FrenziedRegenHP and S.FrenziedRegeneration:IsReady() and Player:BuffDown(S.FrenziedRegenerationBuff) and not Player:HealingAbsorbed() then
    if Cast(S.FrenziedRegeneration, nil, Settings.Guardian.DisplayStyle.Defensives) then return "frenzied_regeneration defensive 2"; end
  end
  if S.Ironfur:IsCastable() and (Player:Rage() >= S.Ironfur:Cost() + 1 and IsTanking and (Player:BuffDown(S.IronfurBuff) or Player:BuffStack(S.IronfurBuff) < 2 and Player:BuffRefreshable(S.Ironfur) or Player:Rage() >= 90)) then
    if Cast(S.Ironfur, nil, Settings.Guardian.DisplayStyle.Defensives) then return "ironfur defensive 4"; end
  end
  if S.Barkskin:IsCastable() and (Player:HealthPercentage() < Settings.Guardian.BarkskinHP and Player:BuffDown(S.IronfurBuff) or Player:HealthPercentage() < Settings.Guardian.BarkskinHP * 0.75) then
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
  -- moonkin_form,if=(druid.owlweave_bear)|(covenant.night_fae&talent.balance_affinity.enabled)
  -- heart_of_the_Wild,if=talent.heart_of_the_wild.enabled&(druid.catweave_bear|druid.owlweave_bear|talent.balance_affinity.enabled)
  -- prowl,if=druid.catweave_bear
  -- NOTE: Not handling cat-weaving or owl-weaving, so skipping above 4 lines
  -- bear_form,if=((!druid.owlweave_bear&!druid.catweave_bear)&(!covenant.night_fae))|((!druid.owlweave_bear&!druid.catweave_bear)&(covenant.night_fae&talent.restoration_affinity.enabled))
  if S.BearForm:IsCastable() and (Player:BuffDown(S.BearForm)) then
    if Cast(S.BearForm) then return "bear_form precombat 2"; end
  end
  -- wrath,if=druid.owlweave_bear&!covenant.night_fae
  -- starfire,if=druid.owlweave_bear&covenant.night_fae
  -- NOTE: Not handling cat-weaving or owl-weaving
  -- fleshcraft,if=soulbind.pustule_eruption.enabled|soulbind.volatile_solvent.enabled,interrupt_immediate=1,interrupt_global=1,interrupt_if=soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 4"; end
  end
  -- Manually added: wild_charge
  if S.WildCharge:IsCastable() and (Target:IsInRange(25) and not Target:IsInRange(8)) then
    if Cast(S.WildCharge) then return "wild_charge precombat 6"; end
  end
  -- Manually added: mangle
  if S.Mangle:IsCastable() and Target:IsInMeleeRange(5) then
    if Cast(S.Mangle) then return "mangle precombat 8"; end
  end
  -- Manually added: thrash_bear
  if S.Thrash:IsCastable() and Target:IsInRange(8) then
    if Cast(S.Thrash) then return "thrash precombat 10"; end
  end
  -- Manually added: moonfire
  if S.Moonfire:IsCastable() then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire precombat 12"; end
  end
end

local function OwlConvoke()
  -- moonkin_form
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&!buff.heart_of_the_wild.up
  -- convoke_the_spirits,if=soulbind.first_strike.enabled&buff.first_strike.up
  -- starfire,if=eclipse.any_next|eclipse.solar_next
  -- wrath,if=eclipse.any_next|eclipse.lunar_next
  -- convoke_the_spirits,if=talent.heart_of_the_wild.enabled&buff.heart_of_the_wild.up
  -- convoke_the_spirits,if=talent.heart_of_the_wild.enabled&cooldown.heart_of_the_wild.remains>15
  -- convoke_the_spirits,if=!talent.heart_of_the_wild.enabled
end

local function CatConvoke()
  -- cat_form
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&!buff.heart_of_the_wild.up
  -- convoke_the_spirits,if=soulbind.first_strike.enabled&buff.first_strike.up
  -- convoke_the_spirits,if=talent.heart_of_the_wild.enabled&buff.heart_of_the_wild.up
  -- convoke_the_spirits,if=talent.heart_of_the_wild.enabled&cooldown.heart_of_the_wild.remains>15
  -- convoke_the_spirits,if=!talent.heart_of_the_wild.enabled
end

local function Bear()
  -- barkskin,if=!buff.bear_form.up&cooldown.barkskin.remains<=0&!druid.catweave_bear
  if S.Barkskin:IsReady() and (Player:BuffDown(S.BearForm) and S.Barkskin:CooldownRemains() <= 0) then
    if Cast(S.Barkskin, nil, Settings.Guardian.DisplayStyle.Defensives) then return "barkskin bear 2"; end
  end
  -- bear_form,if=!buff.bear_form.up
  if S.BearForm:IsCastable() and (Player:BuffDown(S.BearForm)) then
    if Cast(S.BearForm) then return "bear_form bear 4"; end
  end
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&(talent.balance_affinity.enabled)
  if S.HeartoftheWild:IsCastable() and (S.BalanceAffinity:IsAvailable()) then
    if Cast(S.HeartoftheWild, Settings.Guardian.GCDasOffGCD.HeartOfTheWild) then return "heart_of_the_wild bear 6"; end
  end
  -- moonfire,cycle_targets=1,if=((!ticking&time_to_die>12&buff.galactic_guardian.up)|(refreshable&time_to_die>12&buff.galactic_guardian.up))&active_enemies<6
  -- moonfire,cycle_targets=1,if=((!ticking&time_to_die>12)|(refreshable&time_to_die>12))&active_enemies<6
  -- Note: Second line should cover both Moonfire lines...
  if S.Moonfire:IsReady() then
    if Everyone.CastCycle(S.Moonfire, MeleeEnemies8y, EvaluateCycleMoonfire, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 8"; end
  end
  -- ravenous_frenzy,if=(((trinket.1.is.cache_of_acquired_treasures|trinket.2.is.cache_of_acquired_treasures)&buff.acquired_axe.up))|(!trinket.1.is.cache_of_acquired_treasures&!trinket.2.is.cache_of_acquired_treasures)
  if S.RavenousFrenzy:IsCastable() and CDsON() and ((I.CacheofAcquiredTreasures:IsEquipped() and Player:BuffUp(S.AcquiredAxeBuff)) or not I.CacheofAcquiredTreasures:IsEquipped()) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant) then return "ravenous_frenzy bear 10"; end
  end
  -- convoke_the_spirits,if=!druid.catweave_bear&!druid.owlweave_bear&(trinket.1.is.cache_of_acquired_treasures|trinket.2.is.cache_of_acquired_treasures)
  if S.ConvoketheSpirits:IsCastable() and (I.CacheofAcquiredTreasures:IsEquipped()) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "convoke_the_spirits bear 12"; end
  end
  -- incarnation,if=(!covenant.venthyr&((trinket.1.is.cache_of_acquired_treasures|trinket.2.is.cache_of_acquired_treasures)&buff.acquired_axe.up))
  if S.Incarnation:IsCastable() and (CovenantID ~= 2 and I.CacheofAcquiredTreasures:IsEquipped() and Player:BuffUp(S.AcquiredAxeBuff)) then
    if Cast(S.Incarnation, Settings.Guardian.OffGCDasOffGCD.Incarnation) then return "incarnation bear 14"; end
  end
  -- use_item,slot=trinket1,if=trinket.1.is.cache_of_acquired_treasures&buff.acquired_axe.up
  -- use_item,slot=trinket2,if=trinket.2.is.cache_of_acquired_treasures&buff.acquired_axe.up
  if I.CacheofAcquiredTreasures:IsEquippedAndReady() and (Player:BuffUp(S.AcquiredAxeBuff)) then
    if Cast(I.CacheofAcquiredTreasures, nil, Settings.Commons.DisplayStyle.Trinkets) then return "cache_of_acquired_treasures bear 16"; end
  end
  -- use_item,name=gavel_of_the_first_arbiter
  if I.GaveloftheFirstArbiter:IsEquippedAndReady() then
    if Cast(I.GaveloftheFirstArbiter, nil, Settings.Commons.DisplayStyle.Items) then return "gavel_of_the_first_arbiter bear 18"; end
  end
  -- use_item,name=wraps_of_electrostatic_potential
  if I.WrapsofElectrostaticPotential:IsEquippedAndReady() then
    if Cast(I.WrapsofElectrostaticPotential, nil, Settings.Commons.DisplayStyle.Items) then return "wraps_of_electrostatic_potential bear 20"; end
  end
  -- use_item,name=ring_of_collapsing_futures
  if I.RingofCollapsingFutures:IsEquippedAndReady() then
    if Cast(I.RingofCollapsingFutures, nil, Settings.Commons.DisplayStyle.Items) then return "ring_of_collapsing_futures bear 22"; end
  end
  -- use_item,name=jotungeirr_destinys_call,if=covenant.venthyr
  if I.Jotungeirr:IsEquippedAndReady() and (CovenantID == 2) then
    if Cast(I.Jotungeirr, nil, Settings.Commons.DisplayStyle.Items) then return "jotungeirr_destinys_call bear 24"; end
  end
  -- use_item,slot=trinket1,if=!buff.prowl.up&covenant.venthyr&!trinket.1.is.cache_of_acquired_treasures&(!buff.acquired_axe.up&!buff.acquired_sword.up&!buff.acquired_wand.up)|!buff.prowl.up&!covenant.venthyr&!trinket.1.is.cache_of_acquired_treasures&(!buff.acquired_axe.up&!buff.acquired_sword.up&!buff.acquired_wand.up)
  -- Note: Simplified APL. It checks the same thing for venthyr and non-venthyr.
  if trinket1:IsEquippedAndReady() and (trinket1:ID() ~= I.CacheofAcquiredTreasures:ID() and Player:BuffDown(S.AcquiredAxeBuff) and Player:BuffDown(S.AcquiredSwordBuff) and Player:BuffDown(S.AcquiredWandBuff)) then
    if Cast(trinket1, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket1 bear 26"; end
  end
  -- use_item,slot=trinket2,if=!buff.prowl.up&covenant.venthyr&!trinket.2.is.cache_of_acquired_treasures&(!buff.acquired_axe.up&!buff.acquired_sword.up&!buff.acquired_wand.up)|!buff.prowl.up&!covenant.venthyr&!trinket.2.is.cache_of_acquired_treasures&(!buff.acquired_axe.up&!buff.acquired_sword.up&!buff.acquired_wand.up)
  -- Note: Simplified APL. It checks the same thing for venthyr and non-venthyr.
  if trinket2:IsEquippedAndReady() and (trinket2:ID() ~= I.CacheofAcquiredTreasures:ID() and Player:BuffDown(S.AcquiredAxeBuff) and Player:BuffDown(S.AcquiredSwordBuff) and Player:BuffDown(S.AcquiredWandBuff)) then
    if Cast(trinket2, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket2 bear 28"; end
  end
  -- potion,if=covenant.venthyr&buff.incarnation.remains>=24&buff.incarnation.remains<=25
  -- Note: Extended time frame to better handle a real player's reaction time
  if Settings.Commons.Enabled.Potions and I.PotionofPhantomFire:IsReady() and (CovenantID == 2 and Player:BuffRemains(S.IncarnationBuff) >= 23 and Player:BuffRemains(S.IncarnationBuff) <= 26) then
    if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion bear 30"; end
  end
  -- barkskin,if=buff.bear_form.up
  if S.Barkskin:IsReady() and (Player:BuffUp(S.BearForm)) then
    if Cast(S.Barkskin, nil, Settings.Guardian.DisplayStyle.Defensives) then return "barkskin bear 32"; end
  end
  -- convoke_the_spirits,if=!druid.catweave_bear&!druid.owlweave_bear
  if S.ConvoketheSpirits:IsCastable() and CDsON() then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInMeleeRange(5)) then return "convoke_the_spirits bear 34"; end
  end
  -- berserk_bear,if=(buff.ravenous_frenzy.up|!covenant.venthyr)
  if S.Berserk:IsCastable() and IsTanking and (Player:BuffUp(S.RavenousFrenzyBuff) or CovenantID ~= 2) then
    if Cast(S.Berserk, Settings.Guardian.OffGCDasOffGCD.Berserk) then return "berserk bear 36"; end
  end
  -- incarnation,if=(buff.ravenous_frenzy.up|!covenant.venthyr)
  if S.Incarnation:IsCastable() and IsTanking and (Player:BuffUp(S.RavenousFrenzyBuff) or CovenantID ~= 2) then
    if Cast(S.Incarnation, Settings.Guardian.OffGCDasOffGCD.Incarnation) then return "incarnation bear 38"; end
  end
  -- berserking,if=(buff.berserk_bear.up|buff.incarnation_guardian_of_ursoc.up)
  if S.Berserking:IsCastable() and (Player:BuffUp(S.BerserkBuff) or Player:BuffUp(S.IncarnationBuff)) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking bear 40"; end
  end
  -- empower_bond
  if S.EmpowerBond:IsCastable() then
    if Cast(S.EmpowerBond, nil, Settings.Commons.DisplayStyle.Covenant) then return "empower_bond bear 42"; end
  end
  -- adaptive_swarm,if=(!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>3)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<5&dot.adaptive_swarm_damage.ticking)
  if S.AdaptiveSwarm:IsCastable() and (Target:DebuffDown(S.AdaptiveSwarmDebuff) and not S.AdaptiveSwarm:InFlight() and (Target:DebuffDown(S.AdaptiveSwarmDebuff) or Player:BuffRemains(S.AdaptiveSwarmHeal) > 3) or Target:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and Target:DebuffRemains(S.AdaptiveSwarmDebuff) < 5 and Target:DebuffUp(S.AdaptiveSwarmDebuff)) then
    if Cast(S.AdaptiveSwarm, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm bear 44"; end
  end
  -- moonfire,if=buff.galactic_guardian.up&active_enemies<3
  if S.Moonfire:IsReady() and (Player:BuffUp(S.GalacticGuardianBuff) and MeleeEnemies8yCount < 3) then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bear 46"; end
  end
  -- thrash_bear,target_if=refreshable|dot.thrash_bear.stack<3|(dot.thrash_bear.stack<4&runeforge.luffainfused_embrace.equipped)|active_enemies>=4|buff.berserk_bear.up&buff.berserk_bear.remains<=gcd+0.5
  if S.Thrash:IsCastable() then
    if Everyone.CastCycle(S.Thrash, MeleeEnemies8y, EvaluateCycleThrash, not Target:IsInMeleeRange(8)) then return "thrash bear 48"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption.enabled&((cooldown.thrash_bear.remains>0&cooldown.mangle.remains>0)&(dot.moonfire.remains>=3)&(buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&buff.galactic_guardian.down))|soulbind.volatile_solvent.enabled,interrupt_immediate=1,interrupt_global=1,interrupt_if=soulbind.volatile_solvent&(cooldown.thrash_bear.remains>0&cooldown.mangle.remains>0)
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() and ((S.Thrash:CooldownRemains() > 0 and S.Mangle:CooldownRemains() > 0) and (Target:DebuffRemains(S.MoonfireDebuff) >= 3) and (Player:BuffDown(S.IncarnationBuff) and Player:BuffDown(S.BerserkBuff) and Player:BuffDown(S.GalacticGuardianBuff))) or S.VolatileSolvent:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft bear 50"; end
  end
  -- swipe,if=buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&active_enemies>=4
  if S.Swipe:IsCastable() and (Player:BuffDown(S.IncarnationBuff) and Player:BuffDown(S.BerserkBuff) and MeleeEnemies8yCount >= 4) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bear 52"; end
  end
  -- maul,if=(buff.incarnation.up)&active_enemies<3&(buff.tooth_and_claw.stack>=2)|(buff.tooth_and_claw.up&buff.tooth_and_claw.remains<1.5)&active_enemies<3|(buff.berserk_bear.up|buff.incarnation.up)&(buff.savage_combatant.stack>=3)&active_enemies<3|!conduit.savage_combatant.enabled&(buff.berserk_bear.up|buff.incarnation.up)&active_enemies<3&!runeforge.ursocs_fury_remembered.equipped|(buff.savage_combatant.stack>=3)&active_enemies<3|!conduit.savage_combatant.enabled&active_enemies<3&(!buff.berserk_bear.up&!buff.incarnation.up)
  if S.Maul:IsReady() and UseMaul and (Player:BuffUp(S.IncarnationBuff) and MeleeEnemies8yCount < 3 and Player:BuffStack(S.ToothandClawBuff) >= 2 or Player:BuffUp(S.ToothandClawBuff) and Player:BuffRemains(S.ToothandClawBuff) < 1.5 and MeleeEnemies8yCount < 3 or (Player:BuffUp(S.BerserkBuff) or Player:BuffUp(S.IncarnationBuff)) and Player:BuffStack(S.SavageCombatantBuff) >= 3 and MeleeEnemies8yCount < 3 or (not S.SavageCombatant:ConduitEnabled()) and (Player:BuffUp(S.BerserkBuff) or Player:BuffUp(S.IncarnationBuff)) and MeleeEnemies8yCount < 3 and (not UrsocsFuryEquipped) or Player:BuffStack(S.SavageCombatantBuff) >= 3 and MeleeEnemies8yCount < 3 or (not S.SavageCombatant:ConduitEnabled()) and MeleeEnemies8yCount < 3 and Player:BuffDown(S.BerserkBuff) and Player:BuffDown(S.IncarnationBuff)) then
    if Cast(S.Maul, nil, nil, not Target:IsInMeleeRange(5)) then return "maul bear 54"; end
  end
  -- thrash_bear,if=(runeforge.ursocs_fury_remembered.equipped&conduit.savage_combatant.enabled&active_enemies>1)|(runeforge.ursocs_fury_remembered.equipped&!conduit.savage_combatant.enabled&active_enemies>=1)
  if S.Thrash:IsCastable() and ((UrsocsFuryEquipped and S.SavageCombatant:ConduitEnabled() and MeleeEnemies8yCount > 1) or (UrsocsFuryEquipped and (not S.SavageCombatant:ConduitEnabled()) and MeleeEnemies8yCount >= 1)) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bear 56"; end
  end
  -- mangle,if=buff.incarnation.up&active_enemies<=3
  if S.Mangle:IsCastable() and (Player:BuffUp(S.IncarnationBuff) and MeleeEnemies8yCount <= 3) then
    if Cast(S.Mangle, nil, nil, not Target:IsInMeleeRange(5)) then return "mangle bear 58"; end
  end
  -- thrash_bear,if=active_enemies>1
  if S.Thrash:IsCastable() and (MeleeEnemies8yCount > 1) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bear 60"; end
  end
  -- mangle
  if S.Mangle:IsCastable() then
    if Cast(S.Mangle, nil, nil, not Target:IsInMeleeRange(5)) then return "mangle bear 62"; end
  end
  -- pulverize,target_if=dot.thrash_bear.stack>2
  if S.Pulverize:IsReady() then
    if Everyone.CastCycle(S.Pulverize, MeleeEnemies8y, EvaluateCyclePulverize, not Target:IsInMeleeRange(5)) then return "pulverize bear 64"; end
  end
  -- thrash_bear
  if S.Thrash:IsCastable() then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bear 66"; end
  end
  -- swipe_bear
  if S.Swipe:IsCastable() then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bear 68"; end
  end
  -- ironfur,if=rage>=60&buff.ironfur.stack<2&conduit.savage_combatant.enabled&active_enemies<3|!conduit.savage_combatant.enabled&rage>=42&buff.ironfur.down&active_enemies<3|active_enemies>=3&rage>80&buff.ironfur.stack<7
  -- Handled via Defensives()
end

local function CatWeave()
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&!buff.heart_of_the_wild.up&!buff.cat_form.up
  -- cat_form,if=!buff.cat_form.up
  -- rake,if=buff.prowl.up
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&!buff.heart_of_the_wild.up
  -- empower_bond,if=druid.catweave_bear
  -- rake,if=dot.rake.refreshable|energy<45
  -- rip,if=dot.rip.refreshable&combo_points>=1
  -- convoke_the_spirits,if=druid.catweave_bear
  -- ferocious_bite,if=combo_points>=4&energy>50
  -- adaptive_swarm,if=(!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>3)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<5&dot.adaptive_swarm_damage.ticking)
  -- fleshcraft,if=soulbind.pustule_eruption.enabled&energy<35|soulbind.volatile_solvent.enabled,interrupt_immediate=1,interrupt_global=1,interrupt_if=soulbind.volatile_solvent&energy<35
  -- swipe
end

local function OwlWeave()
  -- heart_of_the_wild,if=talent.heart_of_the_wild.enabled&!buff.heart_of_the_wild.up&!buff.moonkin_form.up
  -- moonkin_form,if=!buff.moonkin_form.up
  -- starsurge
  -- barkskin,if=(covenant.night_fae&cooldown.convoke_the_spirits.remains<=1&runeforge.legacy_of_the_sleeper.equipped)
  -- convoke_the_spirits,if=runeforge.legacy_of_the_sleeper.equipped
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
    -- use_item,name=jotungeirr_destinys_call,if=!buff.prowl.up&!covenant.venthyr
    if I.Jotungeirr:IsEquippedAndReady() and (CovenantID ~= 2) then
      if Cast(I.Jotungeirr, nil, Settings.Commons.DisplayStyle.Items) then return "jotungeirr_destinys_call main 2"; end
    end
    -- use_item,slot=trinket1,if=!buff.prowl.up&!covenant.venthyr&!trinket.1.is.cache_of_acquired_treasures&(!buff.acquired_axe.up&!buff.acquired_sword.up&!buff.acquired_wand.up)
    if trinket1:IsEquippedAndReady() and (CovenantID ~= 2 and trinket1:ID() ~= I.CacheofAcquiredTreasures:ID() and (Player:BuffDown(S.AcquiredAxeBuff) and Player:BuffDown(S.AcquiredSwordBuff) and Player:BuffDown(S.AcquiredWandBuff))) then
      if Cast(trinket1, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket1 main 4"; end
    end
    -- use_item,slot=trinket2,if=!buff.prowl.up&!covenant.venthyr&!trinket.2.is.cache_of_acquired_treasures&(!buff.acquired_axe.up&!buff.acquired_sword.up&!buff.acquired_wand.up)
    if trinket2:IsEquippedAndReady() and (CovenantID ~= 2 and trinket2:ID() ~= I.CacheofAcquiredTreasures:ID() and (Player:BuffDown(S.AcquiredAxeBuff) and Player:BuffDown(S.AcquiredSwordBuff) and Player:BuffDown(S.AcquiredWandBuff))) then
      if Cast(trinket2, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket2 main 6"; end
    end
    -- potion,if=!covenant.venthyr&(((talent.heart_of_the_wild.enabled&buff.heart_of_the_wild.up)&(druid.catweave_bear|druid.owlweave_bear)&!buff.prowl.up)|((buff.berserk_bear.up|buff.incarnation_guardian_of_ursoc.up)&(!druid.catweave_bear&!druid.owlweave_bear)))
    if Settings.Commons.Enabled.Potions and I.PotionofPhantomFire:IsReady() and (CovenantID ~= 2 and (Player:BuffUp(S.BerserkBuff) or Player:BuffUp(S.Incarnation))) then
      if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 8"; end
    end
    -- run_action_list,name=catweave,if=druid.catweave_bear&!covenant.venthyr&buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&((cooldown.thrash_bear.remains>0&cooldown.mangle.remains>0&dot.moonfire.remains>=gcd+0.5&rage<40&buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&buff.galactic_guardian.down)|(buff.cat_form.up&energy>25)|(dot.rake.refreshable&dot.rip.refreshable)|(runeforge.oath_of_the_elder_druid.equipped&!buff.oath_of_the_elder_druid.up&(buff.cat_form.up&energy>20)&buff.heart_of_the_wild.remains<=10)|(covenant.kyrian&cooldown.empower_bond.remains<=1&active_enemies<2)|(buff.heart_of_the_wild.up&energy>90))
    -- run_action_list,name=catweave,if=druid.catweave_bear&covenant.venthyr&((cooldown.thrash_bear.remains>0&cooldown.mangle.remains>0&dot.moonfire.remains>=gcd+0.5&rage<40&buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&buff.galactic_guardian.down)|(buff.cat_form.up&energy>25)|(dot.rake.refreshable&dot.rip.refreshable&rage<40&buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&buff.galactic_guardian.down))
    -- Skipping, as we're not handling cat-weaving
    -- run_action_list,name=owlweave,if=druid.owlweave_bear&buff.incarnation_guardian_of_ursoc.down&buff.berserk_bear.down&((cooldown.thrash_bear.remains>0&cooldown.mangle.remains>0&buff.galactic_guardian.down)|(buff.moonkin_form.up&dot.sunfire.refreshable)|(runeforge.oath_of_the_elder_druid.equipped&!buff.oath_of_the_elder_druid.up)|(covenant.night_fae&cooldown.convoke_the_spirits.remains<=1))
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
  HR.Print("Guardian Druid rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(104, APL, OnInit)
