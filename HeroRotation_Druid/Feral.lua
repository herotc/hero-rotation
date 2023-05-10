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
-- Num/Bool Helper Functions
local num         = HR.Commons.Everyone.num
local bool        = HR.Commons.Everyone.bool

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
  I.AlgetharPuzzleBox:ID(),
  I.ManicGrieftorch:ID(),
}

-- Rotation Variables
local VarNeedBT, VarAlign3Mins, VarLastConvoke, VarLastZerk, VarZerkBiteweave
local ComboPoints, ComboPointsDeficit
local BossFightRemains = 11111
local FightRemains = 11111

-- Enemy Variables
local EnemiesMelee, EnemiesCountMelee
local Enemies11y, EnemiesCount11y

-- Berserk/Incarnation Variables
local BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk

-- Event Registration
HL:RegisterForEvent(function()
  BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.AdaptiveSwarm:RegisterInFlightEffect(391889)
  S.AdaptiveSwarm:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.AdaptiveSwarm:RegisterInFlightEffect(391889)
S.AdaptiveSwarm:RegisterInFlight()

-- Interrupt Stuns
local InterruptStuns = {
  { S.MightyBash, "Cast Mighty Bash (Interrupt)", function () return true; end },
}

-- PMultiplier and Damage Registrations
local function ComputeRakePMultiplier()
  return Player:StealthUp(true, true) and 1.6 or 1
end
S.Rake:RegisterPMultiplier(S.RakeDebuff, ComputeRakePMultiplier)

S.Shred:RegisterDamageFormula(
  function()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() *
      -- Shred Modifier
      0.7762 *
      -- Stealth Modifier
      (Player:StealthUp(true) and 1.6 or 1) *
      -- Versatility Modifier
      (1 + Player:VersatilityDmgPct() / 100)
  end
)

S.Thrash:RegisterDamageFormula(
  function()
    return
      -- Immediate Damage
      (Player:AttackPowerDamageMod() * 0.1272) +
      -- Bleed Damage
      (Player:AttackPowerDamageMod() * 0.4055)
  end
)

-- Functions for Bloodtalons
local BtTriggers = {
  S.Rake,
  S.LIMoonfire,
  S.Thrash,
  S.BrutalSlash,
  S.Swipe,
  S.Shred,
  S.FeralFrenzy,
}

local function DebuffRefreshAny(Enemies, Spell)
  for _, Enemy in pairs(Enemies) do
    if Enemy:DebuffRefreshable(Spell) then
      return true
    end
  end
  return false
end

local function LowRakePMult(Enemies)
  local Lowest = nil
  for _, Enemy in pairs(Enemies) do
    local EnemyPMult = Enemy:PMultiplier(S.Rake)
    if (not Lowest) or EnemyPMult < Lowest then
      Lowest = EnemyPMult
    end
  end
  return Lowest
end

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

local function TicksGainedOnRefresh(Spell, Tar)
  if not Tar then Tar = Target end
  local AddedDuration = 0
  local MaxDuration = 0
  -- Added TickTime variable, as Rake and Moonfire don't have tick times in DBC
  local TickTime = 0
  if Spell == S.RipDebuff then
    AddedDuration = (4 + ComboPoints * 4)
    MaxDuration = 31.2
    TickTime = Spell:TickTime()
  else
    AddedDuration = Spell:BaseDuration()
    MaxDuration = Spell:MaxDuration()
    TickTime = Spell:TickTime()
  end

  local OldTicks = Tar:DebuffTicksRemain(Spell)
  local OldTime = Tar:DebuffRemains(Spell)
  local NewTime = AddedDuration + OldTime
  if NewTime > MaxDuration then NewTime = MaxDuration end
  local NewTicks = NewTime / TickTime
  if (not OldTicks) then OldTicks = 0 end
  local TicksAdded = NewTicks - OldTicks
  return TicksAdded
end

-- CastCycle/CastTargetIf Functions
-- CastTargetIf Filters
local function EvaluateTargetIfFilterRakeTicks(TargetUnit)
  -- target_if=max:druid.rake.ticks_gained_on_refresh
  return (TicksGainedOnRefresh(S.RakeDebuff, TargetUnit))
end

local function EvaluateTargetIfFilterTTD(TargetUnit)
  -- target_if=min:target.time_to_die
  return (TargetUnit:TimeToDie())
end

-- CastTargetIf Conditions
local function EvaluateTargetIfBrutalSlashAoeBuilder(TargetUnit)
  -- if=cooldown.brutal_slash.full_recharge_time<4|target.time_to_die<5
  return (S.BrutalSlash:FullRechargeTime() < 4 or TargetUnit:TimeToDie() < 5)
end

local function EvaluateTargetIfBrutalSlashBT(TargetUnit)
  -- if=cooldown.brutal_slash.full_recharge_time<4|target.time_to_die<5&buff.bt_brutal_slash.down
  return (S.BrutalSlash:FullRechargeTime() < 4 or TargetUnit:TimeToDie() < 5 and BTBuffDown(S.BrutalSlash))
end

local function EvaluateTargetIfLIMoonfireBT(TargetUnit)
  -- target_if=max:ticks_gained_on_refresh
  return (TicksGainedOnRefresh(S.LIMoonfireDebuff, TargetUnit))
end

local function EvaluateTargetIfRakeAoeBuilder(TargetUnit)
  -- if=buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier
  return (Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake))
end

local function EvaluateTargetIfRakeBloodtalons(TargetUnit)
  -- if=(refreshable|1.4*persistent_multiplier>dot.rake.pmultiplier)&buff.bt_rake.down
  return ((TargetUnit:DebuffRefreshable(S.RakeDebuff) or 1.4 * Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake)) and BTBuffDown(S.Rake))
end

-- CastCycle Conditions
local function EvaluateCycleAdaptiveSwarm(TargetUnit)
  -- target_if=((!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&(dot.adaptive_swarm_damage.stack<3|!dot.adaptive_swarm_heal.stack>1)&!action.adaptive_swarm_heal.in_flight&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight)&target.time_to_die>5|active_enemies>2&!dot.adaptive_swarm_damage.ticking&energy<35&target.time_to_die>5
  return (((TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) or TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 2) and (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 or Player:BuffStack(S.AdaptiveSwarmHeal) <= 1) and (not S.AdaptiveSwarm:InFlight())) and TargetUnit:TimeToDie() > 5 or EnemiesCount11y > 2 and TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) and Player:Energy() < 35 and TargetUnit:TimeToDie() > 5)
end

local function EvaluateCycleLIMoonfire(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.LIMoonfireDebuff))
end

local function EvaluateCycleRakeAoeBuilder(TargetUnit)
  -- target_if=buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier|refreshable
  return (Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake) or TargetUnit:DebuffRefreshable(S.RakeDebuff))
end

local function EvaluateCycleRake(TargetUnit)
  -- target_if=1.4*persistent_multiplier>dot.rake.pmultiplier&buff.bt_rake.down
  -- bt_rake check handled before CastCycle
  return (1.4 * Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake))
end

local function EvaluateCycleRip(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.RipDebuff))
end

local function EvaluateCycleThrash(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.ThrashDebuff))
end

-- APL Functions
local function Precombat()
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and (Player:BuffDown(S.MarkoftheWildBuff, true) or Everyone.GroupBuffMissing(S.MarkoftheWildBuff)) then
    if Cast(S.MarkoftheWild, Settings.Commons.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat"; end
  end
  -- cat_form,if=!buff.cat_form.up
  if S.CatForm:IsCastable() then
    if Cast(S.CatForm) then return "cat_form precombat 2"; end
  end
  -- heart_of_the_wild
  if S.HeartoftheWild:IsCastable() then
    if Cast(S.HeartoftheWild) then return "heart_of_the_wild precombat 4"; end
  end
  -- use_item,name=algethar_puzzle_box
  if I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 6"; end
  end
  -- prowl,if=!buff.prowl.up
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

local function Variables()
  -- variable,name=need_bt,value=talent.bloodtalons.enabled&buff.bloodtalons.stack<2
  VarNeedBT = (S.Bloodtalons:IsAvailable() and Player:BuffStack(S.BloodtalonsBuff) < 2)
  -- variable,name=align_3minutes,value=spell_targets.swipe_cat=1&!fight_style.dungeonslice
  local DungeonSlice = Player:IsInParty() and not Player:IsInRaid()
  VarAlign3Mins = EnemiesCount11y == 1 and not DungeonSlice
  -- variable,name=lastConvoke,value=fight_remains>cooldown.convoke_the_spirits.remains+3&((talent.ashamanes_guidance.enabled&fight_remains<(cooldown.convoke_the_spirits.remains+60))|(!talent.ashamanes_guidance.enabled&fight_remains<(cooldown.convoke_the_spirits.remains+120)))
  VarLastConvoke = FightRemains > S.ConvoketheSpirits:CooldownRemains() + 3 and ((S.AshamanesGuidance:IsAvailable() and FightRemains < S.ConvoketheSpirits:CooldownRemains() + 60) or ((not S.AshamanesGuidance:IsAvailable()) and FightRemains < S.ConvoketheSpirits:CooldownRemains() + 12))
  -- variable,name=lastZerk,value=fight_remains>(30+(cooldown.bs_inc.remains%1.6))&((talent.berserk_heart_of_the_lion.enabled&fight_remains<(90+(cooldown.bs_inc.remains%1.6)))|(!talent.berserk_heart_of_the_lion.enabled&fight_remains<(180+cooldown.bs_inc.remains)))
  VarLastZerk = FightRemains > (30 + (BsInc:CooldownRemains() / 1.6)) and ((S.BerserkHeartoftheLion:IsAvailable() and FightRemains < (90 + (BsInc:CooldownRemains() / 1.6))) or ((not S.BerserkHeartoftheLion:IsAvailable()) and FightRemains < (180 + BsInc:CooldownRemains())))
  -- variable,name=zerk_biteweave,op=reset
  VarZerkBiteweave = true
end

local function Clearcasting()
  -- thrash_cat,if=refreshable&!talent.thrashing_claws.enabled
  if S.Thrash:IsReady() and (Target:DebuffRefreshable(S.ThrashDebuff) and not S.ThrashingClaws:IsAvailable()) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash clearcasting 2"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>1
  if S.Swipe:IsReady() and (EnemiesCount11y > 1) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe clearcasting 4"; end
  end
  -- brutal_slash,if=spell_targets.brutal_slash>2
  if S.BrutalSlash:IsReady() and (EnemiesCount11y > 2) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(8)) then return "brutal_slash clearcasting 6"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred clearcasting 8"; end
  end
end

local function Builder()
  -- run_action_list,name=clearcasting,if=buff.clearcasting.react
  if (Player:BuffUp(S.Clearcasting)) then
    local ShouldReturn = Clearcasting(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Clearcasting"; end
  end
  -- brutal_slash,if=cooldown.brutal_slash.full_recharge_time<4
  if S.BrutalSlash:IsReady() and (S.BrutalSlash:FullRechargeTime() < 4) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(11)) then return "brutal_slash builder 2"; end
  end
  -- pool_resource,if=!action.rake.ready&(dot.rake.refreshable|(buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier&dot.rake.remains>6))&!buff.clearcasting.react
  if (not S.Rake:IsReady()) and (Target:DebuffRefreshable(S.RakeDebuff) or (Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake) and Target:DebuffRemains(S.RakeDebuff) > 6)) and Player:BuffDown(S.Clearcasting) then
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Rake in Builder()"; end
  end
  -- shadowmeld,if=action.rake.ready&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.prowl.up&!buff.apex_predators_craving.up
  if S.Shadowmeld:IsCastable() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and Player:BuffDown(S.Prowl) and Player:BuffDown(S.ApexPredatorsCravingBuff)) then
    if Cast(S.Shadowmeld) then return "shadowmeld builder 4"; end
  end
  -- rake,if=refreshable|(buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier&dot.rake.remains>6)
  if S.Rake:IsReady() and (Target:DebuffRefreshable(S.RakeDebuff) or (Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake) and Target:DebuffRemains(S.RakeDebuff) > 6)) then
    if Cast(S.Rake, nil, nil, not Target:IsInMeleeRange(8)) then return "rake builder 6"; end
  end
  -- run_action_list,name=clearcasting,if=buff.clearcasting.react
  -- Note: APL notes this is in here a second time to avoid Moonfire being cast during Clearcasting.
  -- The profile should work without this, but keeping it here, since it can't hurt anything to have it twice.
  if (Player:BuffUp(S.Clearcasting)) then
    local ShouldReturn = Clearcasting(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Clearcasting"; end
  end
  -- moonfire_cat,target_if=refreshable
  if S.LIMoonfire:IsReady() then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfire, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat builder 8"; end
  end
  -- thrash_cat,target_if=refreshable&!talent.thrashing_claws.enabled
  if S.Thrash:IsCastable() and (Target:DebuffRefreshable(S.ThrashDebuff) and not S.ThrashingClaws:IsAvailable()) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash builder 10"; end
  end
  -- brutal_slash
  if S.BrutalSlash:IsReady() then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(11)) then return "brutal_slash builder 12"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>1|talent.wild_slashes.enabled
  if S.Swipe:IsReady() and (EnemiesCount11y > 1 or S.WildSlashes:IsAvailable()) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe builder 14"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred builder 16"; end
  end
end

local function AoeBuilder()
  -- brutal_slash,target_if=min:target.time_to_die,if=cooldown.brutal_slash.full_recharge_time<4|target.time_to_die<5
  if S.BrutalSlash:IsReady() then
    if Everyone.CastTargetIf(S.BrutalSlash, Enemies11y, "min", EvaluateTargetIfFilterTTD, EvaluateTargetIfBrutalSlashAoeBuilder, not Target:IsInMeleeRange(11)) then return "brutal_slash aoe_builder 2"; end
  end
  -- thrash_cat,target_if=refreshable,if=buff.clearcasting.react|(spell_targets.thrash_cat>10|(spell_targets.thrash_cat>5&!talent.double_clawed_rake.enabled))&!talent.thrashing_claws
  if S.Thrash:IsReady() and (Player:BuffUp(S.Clearcasting) or (EnemiesCount11y > 10 or (EnemiesCount11y > 5 and not S.DoubleClawedRake:IsAvailable())) and not S.ThrashingClaws:IsAvailable()) then
    if Everyone.CastCycle(S.Thrash, Enemies11y, EvaluateCycleThrash, not Target:IsInMeleeRange(11)) then return "thrash aoe_builder 4"; end
  end
  -- shadowmeld,target_if=max:druid.rake.ticks_gained_on_refresh,if=action.rake.ready&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.prowl.up&!buff.apex_predators_craving.up
  if S.Shadowmeld:IsReady() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (DebuffRefreshAny(Enemies11y, S.RakeDebuff) or LowRakePMult(Enemies11y) < 1.4) and Player:BuffDown(S.Prowl) and Player:BuffDown(S.ApexPredatorsCravingBuff)) then
    if Cast(S.Shadowmeld) then return "shadowmeld aoe_builder 6"; end
  end
  -- shadowmeld,target_if=druid.rake.ticks_gained_on_refresh,if=action.rake.ready&!buff.sudden_ambush.up&dot.rake.pmultiplier<1.4&!buff.prowl.up&!buff.apex_predators_craving.up
  if S.Shadowmeld:IsReady() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and LowRakePMult(Enemies11y) < 1.4 and Player:BuffDown(S.Prowl) and Player:BuffDown(S.ApexPredatorsCravingBuff)) then
    if Cast(S.Shadowmeld) then return "shadowmeld aoe_builder 8"; end
  end
  -- rake,target_if=max:druid.rake.ticks_gained_on_refresh,if=buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier
  if S.Rake:IsReady() and (Player:BuffUp(S.SuddenAmbushBuff)) then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeTicks, EvaluateTargetIfRakeAoeBuilder, not Target:IsInMeleeRange(8)) then return "rake aoe_builder 10"; end
  end
  -- rake,target_if=buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier|refreshable
  if S.Rake:IsReady() then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRakeAoeBuilder, not Target:IsInMeleeRange(8)) then return "rake aoe_builder 12"; end
  end
  -- thrash_cat,target_if=refreshable
  if S.Thrash:IsReady() and (Target:DebuffRefreshable(S.ThrashDebuff)) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash aoe_builder 14"; end
  end
  -- brutal_slash
  if S.BrutalSlash:IsReady() then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(11)) then return "brutal_slash aoe_builder 16"; end
  end
  -- moonfire_cat,target_if=refreshable,if=spell_targets.swipe_cat<5
  if S.LIMoonfire:IsReady() and (EnemiesCount11y < 5) then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfire, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat aoe_builders 18"; end
  end
  -- swipe_cat
  if S.Swipe:IsReady() then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe aoe_builder 20"; end
  end
  -- moonfire_cat,target_if=refreshable
  if S.LIMoonfire:IsReady() then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfire, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat aoe_builders 22"; end
  end
  -- shred,target_if=max:target.time_to_die,if=action.shred.damage>action.thrash_cat.damage&!buff.sudden_ambush.up
  if S.Shred:IsReady() and (S.Shred:Damage() > S.Thrash:Damage() * EnemiesCount11y and Player:BuffDown(S.SuddenAmbushBuff)) then
    if Everyone.CastTargetIf(S.Shred, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, not Target:IsInMeleeRange(8)) then return "shred aoe_builder 24"; end
  end
  -- thrash_cat
  if S.Thrash:IsReady() then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash aoe_builder 26"; end
  end
end

local function Bloodtalons()
  -- brutal_slash,target_if=min:target.time_to_die,if=cooldown.brutal_slash.full_recharge_time<4|target.time_to_die<5&buff.bt_brutal_slash.down
  if S.BrutalSlash:IsReady() then
    if Everyone.CastTargetIf(S.BrutalSlash, Enemies11y, "min", EvaluateTargetIfFilterTTD, EvaluateTargetIfBrutalSlashBT, not Target:IsInMeleeRange(11)) then return "brutal_slash bloodtalons 2"; end
  end
  -- prowl,if=action.rake.ready&gcd.remains=0&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.shadowmeld.up&buff.bt_rake.down&!buff.prowl.up&!buff.apex_predators_craving.up
  if S.Prowl:IsReady() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and Player:BuffDown(S.Shadowmeld) and BTBuffDown(S.Rake) and Player:BuffDown(S.Prowl) and Player:BuffDown(S.ApexPredatorsCravingBuff)) then
    if Cast(S.Prowl) then return "prowl bloodtalons 4"; end
  end
  -- shadowmeld,if=action.rake.ready&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.prowl.up&buff.bt_rake.down&cooldown.feral_frenzy.remains<44&!buff.apex_predators_craving.up
  if S.Shadowmeld:IsReady() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier() < 1.4) and Player:BuffDown(S.Prowl) and BTBuffDown(S.Rake) and S.FeralFrenzy:CooldownRemains() < 44 and Player:BuffDown(S.ApexPredatorsCravingBuff)) then
    if Cast(S.Shadowmeld) then return "shadowmeld bloodtalons 6"; end
  end
  -- rake,target_if=max:druid.rake.ticks_gained_on_refresh,if=(refreshable|1.4*persistent_multiplier>dot.rake.pmultiplier)&buff.bt_rake.down
  if S.Rake:IsReady() and (BTBuffDown(S.Rake)) then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeTicks, EvaluateTargetIfRakeBloodtalons, not Target:IsInRange(8)) then return "rake bloodtalons 8"; end
  end
  -- rake,target_if=1.4*persistent_multiplier>dot.rake.pmultiplier&buff.bt_rake.down
  if S.Rake:IsReady() and (BTBuffDown(S.Rake)) then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRake, not Target:IsInMeleeRange(8)) then return "rake bloodtalons 10"; end
  end
  -- shred,if=buff.bt_shred.down&buff.clearcasting.react&spell_targets.swipe_cat=1
  if S.Shred:IsReady() and (BTBuffDown(S.Shred) and Player:BuffUp(S.Clearcasting) and EnemiesCount11y == 1) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred bloodtalons 12"; end
  end
  -- thrash_cat,target_if=refreshable,if=buff.bt_thrash.down&buff.clearcasting.react&spell_targets.swipe_cat=1&!talent.thrashing_claws.enabled
  if S.Thrash:IsReady() and (DebuffRefreshAny(Enemies11y, S.ThrashDebuff) and BTBuffDown(S.Thrash) and Player:BuffUp(S.Clearcasting) and EnemiesCount11y == 1 and not S.ThrashingClaws:IsAvailable()) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash bloodtalons 14"; end
  end
  -- brutal_slash,if=buff.bt_brutal_slash.down
  if S.BrutalSlash:IsReady() and (BTBuffDown(S.BrutalSlash)) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(8)) then return "brutal_slash bloodtalons 16"; end
  end
  -- moonfire_cat,if=refreshable&buff.bt_moonfire.down&spell_targets.swipe_cat=1
  if S.LIMoonfire:IsReady() and (Target:DebuffRefreshable(S.LIMoonfireDebuff) and BTBuffDown(S.LIMoonfire) and EnemiesCount11y == 1) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat bloodtalons 18"; end
  end
  -- thrash_cat,target_if=refreshable,if=buff.bt_thrash.down&!talent.thrashing_claws.enabled
  if S.Thrash:IsReady() and (DebuffRefreshAny(Enemies11y, S.ThrashDebuff) and BTBuffDown(S.Thrash) and not S.ThrashingClaws:IsAvailable()) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash bloodtalons 20"; end
  end
  -- shred,if=buff.bt_shred.down&spell_targets.swipe_cat=1&!talent.wild_slashes.enabled
  if S.Shred:IsReady() and (BTBuffDown(S.Shred) and EnemiesCount11y == 1 and not S.WildSlashes:IsAvailable()) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred bloodtalons 22"; end
  end
  -- swipe_cat,if=buff.bt_swipe.down&talent.wild_slashes.enabled
  if S.Swipe:IsReady() and (BTBuffDown(S.Swipe) and S.WildSlashes:IsAvailable()) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe bloodtalons 24"; end
  end
  -- moonfire_cat,target_if=max:ticks_gained_on_refresh,if=buff.bt_moonfire.down&spell_targets.swipe_cat<5
  if S.LIMoonfire:IsReady() and (BTBuffDown(S.LIMoonfire) and EnemiesCount11y < 5) then
    if Everyone.CastTargetIf(S.LIMoonfire, Enemies11y, "max", EvaluateTargetIfLIMoonfireBT, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat bloodtalons 26"; end
  end
  -- swipe_cat,if=buff.bt_swipe.down
  if S.Swipe:IsReady() and (BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bloodtalons 28"; end
  end
  -- moonfire_cat,target_if=max:ticks_gained_on_refresh,if=buff.bt_moonfire.down
  if S.LIMoonfire:IsReady() and (BTBuffDown(S.LIMoonfire)) then
    if Everyone.CastTargetIf(S.LIMoonfire, Enemies11y, "max", EvaluateTargetIfLIMoonfireBT, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat bloodtalons 30"; end
  end
  -- shred,target_if=max:target.time_to_die,if=action.shred.damage>action.thrash_cat.damage&buff.bt_shred.down&!buff.sudden_ambush.up
  if S.Shred:IsReady() and (S.Shred:Damage() > S.Thrash:Damage() * EnemiesCount11y and BTBuffDown(S.Shred) and Player:BuffDown(S.SuddenAmbushBuff)) then
    if Everyone.CastTargetIf(S.Shred, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "shred bloodtalons 32"; end
  end
  -- thrash_cat,if=buff.bt_thrash.down
  if S.Thrash:IsReady() and (BTBuffDown(S.Thrash)) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bloodtalons 34"; end
  end
end

local function Finisher()
  -- primal_wrath,if=((dot.primal_wrath.refreshable&!talent.circle_of_life_and_death.enabled)|dot.primal_wrath.remains<6|talent.tear_open_wounds.enabled)&spell_targets.primal_wrath>1&talent.primal_wrath.enabled
  if S.PrimalWrath:IsReady() and (((Target:DebuffRefreshable(S.PrimalWrath) and not S.CircleofLifeandDeath:IsAvailable()) or Target:DebuffRemains(S.PrimalWrath) < 6 or S.TearOpenWounds:IsAvailable()) and EnemiesCount11y > 1 and S.PrimalWrath:IsAvailable()) then
    if Cast(S.PrimalWrath, nil, nil, not Target:IsInMeleeRange(11)) then return "primal_wrath finisher 2"; end
  end
  -- rip,target_if=refreshable
  if S.Rip:IsReady() then
    if Everyone.CastCycle(S.Rip, EnemiesMelee, EvaluateCycleRip, not Target:IsInRange(8)) then return "rip finisher 4"; end
  end
  -- pool_resource,for_next=1,if=!action.tigers_fury.ready&buff.apex_predators_craving.down
  -- ferocious_bite,max_energy=1,target_if=max:target.time_to_die,if=buff.apex_predators_craving.down&(!buff.bs_inc.up|(buff.bs_inc.up&!talent.soul_of_the_forest.enabled))
  if S.FerociousBite:IsReady() and (Player:BuffDown(S.ApexPredatorsCravingBuff) and (Player:BuffDown(BsInc) or (Player:BuffUp(BsInc) and not S.SouloftheForest:IsAvailable()))) then
    if (not S.TigersFury:IsReady()) and Player:BuffDown(S.ApexPredatorsCravingBuff) then
      if CastPooling(S.FerociousBite, Player:EnergyTimeToX(50)) then return "ferocious_bite finisher 6"; end
    elseif Player:Energy() >= 50 then
      if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "ferocious_bite finisher 8"; end
    end
  end
  -- ferocious_bite,target_if=max:target.time_to_die,if=(buff.bs_inc.up&talent.soul_of_the_forest.enabled)|buff.apex_predators_craving.up
  if S.FerociousBite:IsReady() and ((Player:BuffUp(BsInc) and S.SouloftheForest:IsAvailable()) or Player:BuffUp(S.ApexPredatorsCravingBuff)) then
    if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "ferocious_bite finisher 10"; end
  end
end

local function Berserk()
  -- ferocious_bite,target_if=max:target.time_to_die,if=combo_points=5&dot.rip.remains>8&variable.zerk_biteweave&spell_targets.swipe_cat>1
  if S.FerociousBite:IsReady() and (ComboPoints == 5 and VarZerkBiteweave and EnemiesCount11y > 1) then
    if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfFerociousBiteBerserk, not Target:IsInMeleeRange(8)) then return "ferocious_bite berserk 2"; end
  end
  -- call_action_list,name=finisher,if=combo_points=5
  if ComboPoints == 5 then
    local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=bloodtalons,if=combo_points<5&spell_targets.swipe_cat>1
  if ComboPoints < 5 and EnemiesCount11y > 1 then
    local ShouldReturn = Bloodtalons(); if ShouldReturn then return ShouldReturn; end
  end
  -- prowl,if=action.rake.ready&gcd.remains=0&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.shadowmeld.up&cooldown.feral_frenzy.remains<44&!buff.apex_predators_craving.up
  if S.Prowl:IsReady() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and Player:BuffDown(S.Shadowmeld) and S.FeralFrenzy:CooldownRemains() < 44 and Player:BuffDown(S.ApexPredatorsCravingBuff)) then
    if Cast(S.Prowl) then return "prowl berserk 4"; end
  end
  -- shadowmeld,if=action.rake.ready&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.prowl.up&!buff.apex_predators_craving.up
  if S.Shadowmeld:IsCastable() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and Player:BuffDown(S.Prowl) and Player:BuffDown(S.ApexPredatorsCravingBuff)) then
    if Cast(S.Shadowmeld) then return "shadowmeld berserk 6"; end
  end
  -- rake,if=refreshable|(buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier&!dot.rake.refreshable)
  if S.Rake:IsReady() and (Target:DebuffRefreshable(S.RakeDebuff) or (Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake) and not Target:DebuffRefreshable(S.RakeDebuff))) then
    if Cast(S.Rake, nil, nil, not Target:IsInMeleeRange(8)) then return "rake berserk 8"; end
  end
  -- shred,if=active_bt_triggers=2&buff.bt_shred.down
  if S.Shred:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.Shred)) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred berserk 10"; end
  end
  -- brutal_slash,if=active_bt_triggers=2&buff.bt_brutal_slash.down
  if S.BrutalSlash:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.BrutalSlash)) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(11)) then return "brutal_slash berserk 12"; end
  end
  -- moonfire_cat,if=active_bt_triggers=2&buff.bt_moonfire.down
  if S.LIMoonfire:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.LIMoonfire)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat berserk 14"; end
  end
  -- thrash_cat,if=active_bt_triggers=2&buff.bt_thrash.down&!talent.thrashing_claws&variable.need_bt
  if S.Thrash:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.Thrash) and (not S.ThrashingClaws:IsAvailable()) and VarNeedBT) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash berserk 16"; end
  end
  -- moonfire_cat,target_if=refreshable
  if S.LIMoonfire:IsReady() then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfire, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat berserk 18"; end
  end
  -- brutal_slash,if=cooldown.brutal_slash.charges>1
  if S.BrutalSlash:IsReady() and (S.BrutalSlash:Charges() > 1) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(11)) then return "brutal_slash berserk 20"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred berserk 22"; end
  end
end

local function Cooldown()
  -- use_item,name=algethar_puzzle_box,if=fight_remains<35|(!variable.align_3minutes)
  if I.AlgetharPuzzleBox:IsEquippedAndReady() and (FightRemains < 35 or not VarAlign3Mins) then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box cooldown 2"; end
  end
  -- use_item,name=algethar_puzzle_box,if=variable.align_3minutes&(cooldown.bs_inc.remains<3&(!variable.lastZerk|!variable.lastConvoke|(variable.lastConvoke&cooldown.convoke_the_spirits.remains<13)))
  if I.AlgetharPuzzleBox:IsEquippedAndReady() and (VarAlign3Mins and (BsInc:CooldownRemains() < 3 and ((not VarLastZerk) or (not VarLastConvoke) or (VarLastConvoke and S.ConvoketheSpirits:CooldownRemains() < 13)))) then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box cooldown 4"; end
  end
  -- incarnation
  if S.Incarnation:IsReady() then
    if Cast(S.Incarnation, Settings.Feral.GCDasOffGCD.BsInc) then return "incarnation cooldown 6"; end
  end
  -- berserk,if=(!variable.lastZerk)|(fight_remains<23)|(variable.lastZerk&!variable.lastConvoke)
  if S.Berserk:IsReady() and ((not VarLastZerk) or (FightRemains < 23) or (VarLastZerk and not VarLastConvoke)) then
    if Cast(S.Berserk, Settings.Feral.GCDasOffGCD.BsInc) then return "berserk cooldown 8"; end
  end
  -- berserk,if=(variable.lastConvoke&cooldown.convoke_the_spirits.remains<10)
  if S.Berserk:IsReady() and (VarLastConvoke and S.ConvoketheSpirits:CooldownRemains() < 10) then
    if Cast(S.Berserk, Settings.Feral.GCDasOffGCD.BsInc) then return "berserk cooldown 10"; end
  end
  -- berserking,if=!variable.align_3minutes|buff.bs_inc.up
  if S.Berserking:IsCastable() and ((not VarAlign3Mins) or Player:BuffUp(BsInc)) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cooldown 12"; end
  end
  -- potion,if=buff.bs_inc.up|fight_remains<32|(fight_remains<cooldown.bs_inc.remains&variable.lastConvoke&cooldown.convoke_the_spirits.remains<10)
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(BsInc) or FightRemains < 32 or (FightRemains < BsInc:CooldownRemains() and VarLastConvoke and S.ConvoketheSpirits:CooldownRemains() < 10)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldown 14"; end
    end
  end
  -- convoke_the_spirits,if=fight_remains<5|(dot.rip.remains>5&buff.tigers_fury.up&(combo_points<2|(buff.bs_inc.up&combo_points=2))&(!variable.lastConvoke|!variable.lastZerk|buff.bs_inc.up))
  if S.ConvoketheSpirits:IsReady() and (FightRemains < 5 or (Target:DebuffRemains(S.RipDebuff) > 5 and Player:BuffUp(S.TigersFury) and (ComboPoints < 2 or (Player:BuffUp(BsInc) and ComboPoints == 2)) and ((not VarLastConvoke) or (not VarLastZerk) or Player:BuffUp(BsInc)))) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(8)) then return "convoke_the_spirits cooldown 16"; end
  end
  -- use_item,name=manic_grieftorch,target_if=max:target.time_to_die,if=energy.deficit>40
  if I.ManicGrieftorch:IsEquippedAndReady() and (Player:EnergyDeficit() > 40) then
    if Everyone.CastTargetIf(I.ManicGrieftorch, Enemies11y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(40), nil, Settings.Commons.DisplayStyle.Trinkets) then return "manic_grieftorch cooldown 18"; end
  end
  -- use_items
  if (Settings.Commons.Enabled.Trinkets) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
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
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(13, S.SkullBash, Settings.Feral.OffGCDasOffGCD.SkullBash, InterruptStuns); if ShouldReturn then return ShouldReturn; end
    -- prowl,if=buff.bs_inc.down&!buff.prowl.up
    if S.Prowl:IsCastable() and (Player:BuffDown(BsInc)) then
      if Cast(S.Prowl) then return "prowl main 2"; end
    end
    -- cat_form,if=!buff.cat_form.up
    if S.CatForm:IsCastable() then
      if Cast(S.CatForm) then return "cat_form main 4"; end
    end
    -- invoke_external_buff,name=power_infusion
    -- Note: We're not handling external buffs
    -- call_action_list,name=variables
    Variables()
    -- tigers_fury,if=!talent.convoke_the_spirits.enabled&(!buff.tigers_fury.up|energy.deficit>65)
    if S.TigersFury:IsCastable() and CDsON() and ((not S.ConvoketheSpirits:IsAvailable()) and (Player:BuffDown(S.TigersFury) or Player:EnergyDeficit() > 65)) then
      if Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury main 6"; end
    end
    -- tigers_fury,if=talent.convoke_the_spirits.enabled&(!variable.lastConvoke|(variable.lastConvoke&!buff.tigers_fury.up))
    if S.TigersFury:IsCastable() and CDsON() and (S.ConvoketheSpirits:IsAvailable() and ((not VarLastConvoke) or (VarLastConvoke and Player:BuffDown(S.TigersFury)))) then
      if Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury main 8"; end
    end
    -- rake,target_if=1.4*persistent_multiplier>dot.rake.pmultiplier,if=buff.prowl.up|buff.shadowmeld.up
    if S.Rake:IsReady() and (Player:StealthUp(false, true)) then
      if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRake, not Target:IsInMeleeRange(8)) then return "rake main 10"; end
    end
    -- auto_attack,if=!buff.prowl.up&!buff.shadowmeld.up
    -- natures_vigil
    if S.NaturesVigil:IsCastable() then
      if Cast(S.NaturesVigil, Settings.Feral.OffGCDasOffGCD.NaturesVigil) then return "natures_vigil main 11"; end
    end
    -- adaptive_swarm,target_if=((!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&(dot.adaptive_swarm_damage.stack<3|!dot.adaptive_swarm_heal.stack>1)&!action.adaptive_swarm_heal.in_flight&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight)&target.time_to_die>5|active_enemies>2&!dot.adaptive_swarm_damage.ticking&energy<35&target.time_to_die>5,if=!(variable.need_bt&active_bt_triggers=2)
    if S.AdaptiveSwarm:IsReady() and (not (VarNeedBT and CountActiveBtTriggers() == 2)) then
      if Everyone.CastCycle(S.AdaptiveSwarm, Enemies11y, EvaluateCycleAdaptiveSwarm, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm main 12"; end
    end
    -- call_action_list,name=cooldown
    if CDsON() then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    -- feral_frenzy,target_if=max:target.time_to_die,if=combo_points<2|combo_points<3&buff.bs_inc.up
    if S.FeralFrenzy:IsReady() and (ComboPoints < 2 or ComboPoints < 3 and Player:BuffUp(BsInc)) then
      if Everyone.CastTargetIf(S.FeralFrenzy, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "feral_frenzy main 14"; end
    end
    -- ferocious_bite,target_if=max:target.time_to_die,if=buff.apex_predators_craving.up&(spell_targets.swipe_cat=1|!talent.primal_wrath.enabled|!buff.sabertooth.up)&!(variable.need_bt&active_bt_triggers=2)
    if S.FerociousBite:IsReady() and (Player:BuffUp(S.ApexPredatorsCravingBuff) and (EnemiesCount11y == 1 or (not S.PrimalWrath:IsAvailable()) or Player:BuffDown(S.SabertoothBuff)) and not (VarNeedBT and CountActiveBtTriggers() == 2)) then
      if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "ferocious_bite main 16"; end
    end
    -- call_action_list,name=berserk,if=buff.bs_inc.up
    if Player:BuffUp(BsInc) then
      local ShouldReturn = Berserk(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=finisher,if=combo_points>=4&spell_targets.swipe_cat>1
    -- wait,sec=combo_points=5,if=combo_points=4&buff.predator_revealed.react&energy.deficit>40
    -- call_action_list,name=finisher,if=combo_points>=4
    -- Note: Not handling wait line, so combined both finisher lines.
    if ComboPoints >= 4 then
      local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=bloodtalons,if=variable.need_bt&!buff.bs_inc.up&combo_points<5
    if VarNeedBT and Player:BuffDown(BsInc) and ComboPoints < 5 then
      local ShouldReturn = Bloodtalons(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=aoe_builder,if=spell_targets.swipe_cat>1&talent.primal_wrath.enabled
    if (EnemiesCount11y > 1 and S.PrimalWrath:IsAvailable()) then
      local ShouldReturn = AoeBuilder(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Aoe()"; end
    end
    -- call_action_list,name=builder,if=combo_points<5&!buff.bs_inc.up
    if ComboPoints < 5 and Player:BuffDown(BsInc) then
      local ShouldReturn = Builder(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool if nothing else to do
    if (true) then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool Energy"; end
    end
  end
end

local function OnInit()
  S.RipDebuff:RegisterAuraTracking()

  HR.Print("Feral Druid rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(103, APL, OnInit)
