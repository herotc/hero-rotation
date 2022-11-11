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
local CastPooling = HR.CastPooling

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Feral = HR.GUISettings.APL.Druid.Feral
}

-- Spells
local S = Spell.Druid.Feral

-- Items
local I = Item.Druid.Feral
local OnUseExcludes = {--  I.TrinketName:ID(),
}

-- Rotation Variables
local VarsInit = false
local VarSwipeVShred
local VarPWVFB
local ComboPoints, ComboPointsDeficit
local BossFightRemains = 11111
local FightRemains = 11111

-- Enemy Variables
local EnemiesMelee, EnemiesCountMelee
local Enemies11y, EnemiesCount11y

-- Berserk/Incarnation Variables
local BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Legendaries
local DeepFocusEquipped = Player:HasLegendaryEquipped(46)
local FrenzybandEquipped = Player:HasLegendaryEquipped(54)
local CateyeCurioEquipped = Player:HasLegendaryEquipped(57)

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- Event Registration
HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
  DeepFocusEquipped = Player:HasLegendaryEquipped(46)
  FrenzybandEquipped = Player:HasLegendaryEquipped(54)
  CateyeCurioEquipped = Player:HasLegendaryEquipped(57)
  VarInit = false
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk
  VarInit = false
end, "PLAYER_TALENT_UPDATE")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
  VarInit = false
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.AdaptiveSwarm:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.AdaptiveSwarm:RegisterInFlight()

-- Interrupt Stuns
local InterruptStuns = {
  { S.MightyBash, "Cast Mighty Bash (Interrupt)", function () return true; end },
}

-- num/bool Functions
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-- PMultiplier and Damage Registrations
local function ComputeRakePMultiplier()
  return Player:StealthUp(true, true) and 1.6 or 1
end
S.Rake:RegisterPMultiplier(S.RakeDebuff, ComputeRakePMultiplier)

local function SwipeBleedMult()
  return (Target:DebuffUp(S.RipDebuff) or Target:DebuffUp(S.RakeDebuff) or Target:DebuffUp(S.ThrashDebuff)) and 1.2 or 1;
end

-- Functions for Bloodtalons
local BtTriggers = {
  S.Rake,
  S.LIMoonfire,
  S.Thrash,
  S.BrutalSlash,
  S.Swipe,
  S.Shred,
}

local function BTBuffUp(Trigger)
  if not S.Bloodtalons:IsAvailable() then return false end
  return Trigger:TimeSinceLastCast() < math.min(5, S.BloodtalonsBuff:TimeSinceLastAppliedOnPlayer())
end

local function BTBuffDown(Trigger)
  return not BTBuffUp(Trigger)
end

function CountActiveBtTriggers()
  local ActiveTriggers = 0
  for i = 1, #BtTriggers do
    if BTBuffUp(BtTriggers[i]) then ActiveTriggers = ActiveTriggers + 1 end
  end
  return ActiveTriggers
end

local function TicksGainedOnRefresh(Spell)
  local AddedDuration = 0
  local MaxDuration = 0
  -- Added TickTime variable, as Rake and Moonfire don't have tick times in DBC
  local TickTime = 0
  if Spell == S.RipDebuff then
    AddedDuration = (4 + ComboPoints * 4) * mod
    MaxDuration = 31.2
    TickTime = Spell:TickTime()
  else
    AddedDuration = Spell:BaseDuration()
    MaxDuration = Spell:MaxDuration()
    TickTime = Spell:TickTime()
  end

  local OldTicks = Target:DebuffTicksRemain(Spell)
  local OldTime = Target:DebuffRemains(Spell)
  local NewTime = AddedDuration + OldTime
  if NewTime > MaxDuration then NewTime = MaxDuration end
  local NewTicks = NewTime / TickTime
  return NewTicks - OldTicks
end

-- CastCycle/CastTargetIf Functions
local function EvaluateCycleAdaptiveSwarm(TargetUnit)
  -- target_if=((!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&(dot.adaptive_swarm_damage.stack<3|!dot.adaptive_swarm_heal.stack>1)&!action.adaptive_swarm_heal.in_flight&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight)&target.time_to_die>5|active_enemies>2&!dot.adaptive_swarm_damage.ticking&energy<35&target.time_to_die>5
  return (((TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) or TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 2) and (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 or not Player:BuffStack(S.AdaptiveSwarmHeal) > 1) and (not S.AdaptiveSwarm:InFlight())) and TargetUnit:TimeToDie() > 5 or EnemiesCount11y > 2 and TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) and Player:Energy() < 35 and TargetUnit:TimeToDie() > 5)
end

local function EvaluateCycleLIMoonfire(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.LIMoonfireDebuff))
end

local function EvaluateCyclePrimalWrath(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.RipDebuff))
end

local function EvaluateCycleRip(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.RipDebuff))
end

local function EvaluateCycleThrash(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.ThrashDebuff))
end

local function EvaluateTargetIfFilterRake(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.RakeDebuff))
end

local function EvaluateTargetIfFilterRakeTicks(TargetUnit)
  -- target_if=max:druid.rake.ticks_gained_on_refresh
  return (TicksGainedOnRefresh(S.RakeDebuff))
end

local function EvaluateTargetIfRakeBloodtalons(TargetUnit)
  -- if=(!ticking|(1.2*persistent_multiplier>=dot.rake.pmultiplier)|(active_bt_triggers=2&refreshable))&buff.bt_rake.down
  return (TargetUnit:DebuffDown(S.RakeDebuff) or (1.2 * Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake)) or (CountActiveBtTriggers() == 2 and TargetUnit:DebuffRefreshable(S.RakeDebuff)))
end

local function EvaluateTargetIfRake(TargetUnit)
  -- if=refreshable|buff.sudden_ambush.up
  return (TargetUnit:DebuffRefreshable(S.RakeDebuff) or Player:BuffUp(S.SuddenAmbushBuff))
end

local function InitVars()
  -- variable,name=swipe_v_shred,value=2
  VarSwipeVShred = 2
  -- variable,name=pw_v_fb,op=setif,value=0,condition=talent.tear_open_wounds.enabled&talent.rip_and_tear.enabled,value_else=4
  VarPWVFB = (S.TearOpenWounds:IsAvailable() and S.RipandTear:IsAvailable()) and 0 or 4

  VarsInit = true
end

-- APL Functions
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- cat_form
  if S.CatForm:IsCastable() then
    if Cast(S.CatForm) then return "cat_form precombat 2"; end
  end
  -- prowl
  if S.Prowl:IsCastable() then
    if Cast(S.Prowl) then return "prowl precombat 4"; end
  end
  -- Manually added: wild_charge
  if S.WildCharge:IsCastable() and (not Target:IsInRange(8)) then
    if Cast(S.WildCharge, nil, nil, not Target:IsInRange(28)) then return "wild_charge precombat 6"; end
  end
  -- Manually added: rake
  if S.Rake:IsReady() then
    if Cast(S.Rake, nil, nil, not Target:IsInMeleeRange(8)) then return "rake precombat 8"; end
  end
end

local function Clearcasting()
  -- thrash_cat,target_if=refreshable
  if S.Thrash:IsReady() then
    if Everyone.CastCycle(S.Thrash, Enemies11y, EvaluateCycleThrash, not Target:IsInMeleeRange(11)) then return "thrash clearcasting 2"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>variable.swipe_v_shred
  if S.Swipe:IsReady() and (EnemiesCount11y > VarSwipeVShred) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe clearcasting 4"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred clearcasting 6"; end
  end
  -- brutal_slash
  if S.BrutalSlash:IsReady() then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(8)) then return "brutal_slash clearcasting 8"; end
  end
end

local function BuilderCycle()
  -- run_action_list,name=clearcasting,if=buff.clearcasting.react
  if (Player:BuffUp(S.Clearcasting)) then
    local ShouldReturn = Clearcasting(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Clearcasting"; end
  end
  -- rake,target_if=max:ticks_gained_on_refresh,if=refreshable|buff.sudden_ambush.up
  if S.Rake:IsReady() then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeTicks, EvaluateTargetIfRake, not Target:IsInMeleeRange(8)) then return "rake builder_cycle 2"; end
  end
  -- moonfire_cat,target_if=refreshable
  if S.LIMoonfire:IsReady() then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfire, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat builder_cycle 4"; end
  end
  -- pool_resource,for_next=1
  -- thrash_cat,target_if=refreshable
  if S.Thrash:IsCastable() and (Target:DebuffRefreshable(S.ThrashDebuff)) then
    if CastPooling(S.Thrash, Player:EnergyTimeToX(40), not Target:IsInMeleeRange(11)) then return "thrash builder_cycle 6"; end
  end
  -- brutal_slash
  if S.BrutalSlash:IsReady() then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(11)) then return "brutal_slash builder_cycle 8"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>variable.swipe_v_shred
  if S.Swipe:IsReady() and (EnemiesCount11y > VarSwipeVShred) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe builder_cycle 10"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred builder_cycle 12"; end
  end
end

local function BerserkBuilders()
  -- rake,target_if=refreshable
  if S.Rake:IsReady() then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateTargetIfFilterRake, not Target:IsInMeleeRange(8)) then return "rake berserk_builders 2"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>variable.swipe_v_shred
  if S.Swipe:IsReady() and (EnemiesCount11y > VarSwipeVShred) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe berserk_builders 4"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred berserk_builders 6"; end
  end
end

local function Finisher()
  -- primal_wrath,if=spell_targets.primal_wrath>variable.pw_v_fb
  if S.PrimalWrath:IsReady() and (EnemiesCount11y > VarPWVFB) then
    if Cast(S.PrimalWrath, nil, nil, not Target:IsInMeleeRange(11)) then return "primal_wrath finisher 2"; end
  end
  -- primal_wrath,target_if=refreshable,if=spell_targets.primal_wrath>1
  if S.PrimalWrath:IsReady() and (EnemiesCount11y > 1) then
    if Everyone.CastTargetIf(S.PrimalWrath, Enemies11y, EvaluateCyclePrimalWrath, not Target:IsInMeleeRange(11)) then return "primal_wrath finisher 4"; end
  end
  -- rip,target_if=refreshable
  if S.Rip:IsReady() then
    if Everyone.CastCycle(S.Rip, EnemiesMelee, EvaluateCycleRip, not Target:IsInRange(8)) then return "rip finisher 6"; end
  end
  -- pool_resource,for_next=1
  -- ferocious_bite,max_energy=1
  if S.FerociousBite:IsReady() then
    if CastPooling(S.FerociousBite, Player:EnergyTimeToX(50)) then return "ferocious_bite finisher 14"; end
  end
  -- ferocious_bite,if=(buff.bs_inc.up&talent.soul_of_the_forest.enabled)
  if S.FerociousBite:IsReady() and (Player:BuffUp(BsInc) and S.SouloftheForest:IsAvailable()) then
    if Cast(S.FerociousBite, nil, nil, not Target:IsInMeleeRange(8)) then return "ferocious_bite finisher 10"; end
  end
end

local function Cooldown()
  -- berserk
  if S.Berserk:IsReady() then
    if Cast(S.Berserk, Settings.Feral.GCDasOffGCD.BsInc) then return "berserk cooldown 2"; end
  end
  -- incarnation
  if S.Incarnation:IsReady() then
    if Cast(S.Incarnation, Settings.Feral.GCDasOffGCD.BsInc) then return "incarnation cooldown 4"; end
  end
  -- convoke_the_spirits,if=buff.tigers_fury.up&combo_points<3|fight_remains<5
  if S.ConvoketheSpirits:IsReady() and (Player:BuffUp(S.TigersFury) and ComboPoints < 3 or FightRemains < 5) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInMeleeRange(8)) then return "convoke_the_spirits cooldown 6"; end
  end
  if S.ConvoketheSpiritsCov:IsReady() and (Player:BuffUp(S.TigersFury) and ComboPoints < 3 or FightRemains < 5) then
    if Cast(S.ConvoketheSpiritsCov, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInMeleeRange(8)) then return "convoke_the_spirits covenant cooldown 6"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cooldown 8"; end
  end
  -- shadowmeld,if=buff.tigers_fury.up&buff.bs_inc.down&combo_points<4&buff.sudden_ambush.down&dot.rake.pmultiplier<1.6&energy>40&druid.rake.ticks_gained_on_refresh>spell_targets.swipe_cat*2-2&target.time_to_die>5
  if S.Shadowmeld:IsCastable() and (Player:BuffUp(S.TigersFury) and Player:BuffDown(BsInc) and ComboPoints < 4 and Player:BuffDown(S.SuddenAmbushBuff) and Target:PMultiplier(S.Rake) < 1.6 and Player:Energy() > 40 and TicksGainedOnRefresh(S.RakeDebuff) > EnemiesCount11y * 2 - 2 and Target:TimeToDie() > 5) then
    if Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "shadowmeld cooldown 10"; end
  end
  -- potion,if=buff.bs_inc.up|fight_remains<cooldown.bs_inc.remains|fight_remains<25
  if I.PotionofSpectralAgility:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(BsInc) or FightRemains < BsInc:CooldownRemains() or FightRemains < 25) then
    if Cast(I.PotionofSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldown 12"; end
  end
  -- use_items
  if (Settings.Commons.Enabled.Trinkets) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function Owlweaving()
  if (Player:BuffUp(S.MoonkinForm)) then
    -- starsurge
    if S.Starsurge:IsReady() then
      if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge owlweaving 2"; end
    end
    -- sunfire,line_cd=4*gcd
    if S.Sunfire:IsReady() and (S.Sunfire:TimeSinceLastCast() > 4 * Player:GCD()) then
      if Cast(S.Sunfire, nil, nil, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire owlweaving 4"; end
    end
    -- moonfire,line_cd=4*gcd
    if S.Moonfire:IsReady() and (S.Moonfire:TimeSinceLastCast() > 4 * Player:GCD()) then
      if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire owlweaving 6"; end
    end
  end
  -- Manually added: moonkin_form,if=!buff.moonkin_form.up
  if S.MoonkinForm:IsCastable() and (Player:BuffDown(S.MoonkinForm)) then
    if Cast(S.MoonkinForm) then return "moonkin_form owlweave 10"; end
  end
end

local function Bloodtalons()
  -- rake,target_if=max:druid.rake.ticks_gained_on_refresh,if=(!ticking|(1.2*persistent_multiplier>=dot.rake.pmultiplier)|(active_bt_triggers=2&refreshable))&buff.bt_rake.down
  if S.Rake:IsReady() and (BTBuffDown(S.Rake)) then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeTicks, EvaluateTargetIfRakeBloodtalons, not Target:IsInRange(8)) then return "rake bloodtalons 2"; end
  end
  -- lunar_inspiration,if=refreshable&buff.bt_moonfire.down
  if S.LunarInspiration:IsAvailable() and S.LIMoonfire:IsReady() and (Target:DebuffRefreshable(S.LIMoonfireDebuff) and BTBuffDown(S.LIMoonfire)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire bloodtalons 4"; end
  end
  -- thrash_cat,target_if=refreshable&buff.bt_thrash.down
  if S.Thrash:IsReady() and (BTBuffDown(S.Thrash)) then
    if Everyone.CastCycle(S.Thrash, Enemies11y, EvaluateCycleThrash, not Target:IsInMeleeRange(8)) then return "thrash bloodtalons 6"; end
  end
  -- brutal_slash,if=buff.bt_brutal_slash.down
  if S.BrutalSlash:IsReady() and (BTBuffDown(S.BrutalSlash)) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(8)) then return "brutal_slash bloodtalons 8"; end
  end
  -- swipe_cat,if=buff.bt_swipe.down
  if S.Swipe:IsReady() and (BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bloodtalons 10"; end
  end
  -- shred,if=buff.bt_shred.down
  if S.Shred:IsReady() and (BTBuffDown(S.Shred)) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred bloodtalons 12"; end
  end
  -- swipe_cat,if=buff.bt_swipe.down
  if S.Swipe:IsReady() and (BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bloodtalons 14"; end
  end
  -- thrash_cat,if=buff.bt_thrash.down
  if S.Thrash:IsReady() and (BTBuffDown(S.Thrash)) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bloodtalons 16"; end
  end
  -- rake,if=buff.bt_rake.down&combo_points>4
  if S.Rake:IsReady() and (BTBuffDown(S.Rake) and ComboPoints > 4) then
    if Cast(S.Rake, nil, nil, not Target:IsInMeleeRange(8)) then return "rake bloodtalons 18"; end
  end
end

local function APL()
  -- Update Enemies
  if AoEON() then
    EnemiesMelee = Player:GetEnemiesInMeleeRange(8)
    Enemies11y = Player:GetEnemiesInMeleeRange(11)
    EnemiesCountMelee = #EnemiesMelee
    EnemiesCount11y = #Enemies11y
  else
    EnemiesMelee = {}
    Enemies11y = {}
    EnemiesCountMelee = 1
    EnemiesCount11y = 1
  end

  -- Combo Points
  ComboPoints = Player:ComboPoints()
  ComboPointsDeficit = Player:ComboPointsDeficit()

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies11y, false)
    end
  end

  -- cat_form OOC, if setting is true
  if S.CatForm:IsCastable() and Settings.Feral.ShowCatFormOOC then
    if Cast(S.CatForm) then return "cat_form ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Initialize variables, if not yet done
    if not VarsInit then InitVars() end
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(InterruptRange, S.SkullBash, Settings.Feral.OffGCDasOffGCD.SkullBash, InterruptStuns); if ShouldReturn then return ShouldReturn; end
    -- prowl
    if S.Prowl:IsCastable() then
      if Cast(S.Prowl) then return "prowl main 2"; end
    end
    -- tigers_fury,if=energy.deficit>40|buff.bs_inc.up
    if S.TigersFury:IsCastable() and CDsON() and (Player:EnergyDeficit() > 40 or Player:BuffUp(BsInc)) then
      if Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury main 4"; end
    end
    -- cat_form,if=!buff.cat_form.up&energy>50
    if S.CatForm:IsCastable() and (Player:Energy() > 50) then
      if Cast(S.CatForm) then return "cat_form main 6"; end
    end
    -- auto_attack,if=!buff.prowl.up&!buff.shadowmeld.up
    -- call_action_list,name=cooldown
    if CDsON() then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    -- adaptive_swarm,target_if=((!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&(dot.adaptive_swarm_damage.stack<3|!dot.adaptive_swarm_heal.stack>1)&!action.adaptive_swarm_heal.in_flight&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight)&target.time_to_die>5|active_enemies>2&!dot.adaptive_swarm_damage.ticking&energy<35&target.time_to_die>5
    if S.AdaptiveSwarm:IsReady() then
      if Everyone.CastCycle(S.AdaptiveSwarm, Enemies11y, EvaluateCycleAdaptiveSwarm, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm main 8"; end
    end
    -- ferocious_bite,if=buff.apex_predators_craving.up
    if S.FerociousBite:IsReady() and (Player:BuffUp(S.ApexPredatorsCravingBuff)) then
      if Cast(S.FerociousBite, nil, nil, not Target:IsInMeleeRange(8)) then return "ferocious_bite main 10"; end
    end
    -- feral_frenzy,if=combo_points<2
    if S.FeralFrenzy:IsReady() and (ComboPoints < 2) then
      if Cast(S.FeralFrenzy, nil, nil, not Target:IsInMeleeRange(8)) then return "feral_frenzy main 12"; end
    end
    -- call_action_list,name=finisher,if=combo_points=5
    if (ComboPoints == 5) then
      local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=bloodtalons,if=buff.bloodtalons.down
    if (Player:BuffDown(S.BloodtalonsBuff)) then
      local ShouldReturn = Bloodtalons(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=berserk_builders,if=combo_points<5&(buff.bs_inc.up|buff.shadowmeld.up|buff.prowl.up)
    if (ComboPoints < 5 and (Player:BuffUp(BsInc) or Player:StealthUp(true, true))) then
      local ShouldReturn = BerserkBuilders(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=builder_cycle,if=combo_points<5
    if (ComboPoints < 5) then
      local ShouldReturn = BuilderCycle(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=owlweaving,if=buff.bs_inc.down&energy<80
    if (Player:BuffUp(BsInc) and Player:Energy() < 80) then
      local ShouldReturn = Owlweaving(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool if nothing else to do
    if (true) then
      if Cast(S.Pool) then return "Pool Energy"; end
    end
  end
end

local function OnInit()
  S.RipDebuff:RegisterAuraTracking()

  HR.Print("Feral Druid rotation is currently a work in progress, but has been updated for patch 10.0.0.")
end

HR.SetAPL(103, APL, OnInit)
