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
  I.ManicGrieftorch:ID(),
}

-- Rotation Variables
local VarNeedBT
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

-- Event Registration
HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk
end, "PLAYER_TALENT_UPDATE")

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

local function SwipeBleedMult()
  return (Target:DebuffUp(S.RipDebuff) or Target:DebuffUp(S.RakeDebuff) or Target:DebuffUp(S.ThrashDebuff)) and 1.2 or 1;
end

S.Shred:RegisterDamageFormula(
  function()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() *
      -- Shred Modifier
      0.6837 *
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
      (Player:AttackPowerDamageMod() * 0.098) +
      -- Bleed Damage
      (Player:AttackPowerDamageMod() * 0.312)
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
local function EvaluateCycleAdaptiveSwarm(TargetUnit)
  -- target_if=((!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&(dot.adaptive_swarm_damage.stack<3|!dot.adaptive_swarm_heal.stack>1)&!action.adaptive_swarm_heal.in_flight&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight)&target.time_to_die>5|active_enemies>2&!dot.adaptive_swarm_damage.ticking&energy<35&target.time_to_die>5
  return (((TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) or TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 2) and (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 or Player:BuffStack(S.AdaptiveSwarmHeal) <= 1) and (not S.AdaptiveSwarm:InFlight())) and TargetUnit:TimeToDie() > 5 or EnemiesCount11y > 2 and TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) and Player:Energy() < 35 and TargetUnit:TimeToDie() > 5)
end

local function EvaluateCycleLIMoonfire(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.LIMoonfireDebuff))
end

local function EvaluateCycleLIMoonfireAoe(TargetUnit)
  -- target_if=max:((ticks_gained_on_refresh+1)-(spell_targets.swipe_cat*2.492))
  return ((TicksGainedOnRefresh(S.LIMoonfireDebuff, TargetUnit) + 1) - (EnemiesCount11y * 2.492))
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

local function EvaluateTargetIfFilterRakeAoe(TargetUnit)
  -- target_if=max:dot.rake.ticks_gained_on_refresh.pmult
  return (TicksGainedOnRefresh(S.RakeDebuff, TargetUnit))
end

local function EvaluateTargetIfFilterRakeTicks(TargetUnit)
  -- target_if=max:druid.rake.ticks_gained_on_refresh
  return (TicksGainedOnRefresh(S.RakeDebuff, TargetUnit))
end

local function EvaluateTargetIfRake(TargetUnit)
  -- if=refreshable|(buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier&dot.rake.duration>6)
  -- Note: Skipped dot.rake.duration>6, as this should always be true (may have intended .remains?)
  return (TargetUnit:DebuffRefreshable(S.RakeDebuff) or (Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake)))
end

local function EvaluateTargetIfRakeAoe(TargetUnit)
  -- if=((dot.rake.ticks_gained_on_refresh.pmult*(1+talent.doubleclawed_rake.enabled))>(spell_targets.swipe_cat*0.216+3.32))
  return ((TicksGainedOnRefresh(S.RakeDebuff, TargetUnit) * (1 + num(S.DoubleClawedRake:IsAvailable()))) > (EnemiesCount11y * 0.216 + 3.32))
end

local function EvaluateTargetIfRakeBloodtalons(TargetUnit)
  -- if=(refreshable|1.4*persistent_multiplier>dot.rake.pmultiplier)&buff.bt_rake.down
  return ((TargetUnit:DebuffRefreshable(S.RakeDebuff) or 1.4 * Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake)) and BTBuffDown(S.Rake))
end

-- APL Functions
local function Precombat()
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and (Player:BuffDown(S.MarkoftheWildBuff, true) or Everyone.GroupBuffMissing(S.MarkoftheWildBuff)) then
    if Cast(S.MarkoftheWild, Settings.Commons.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat"; end
  end
  -- use_item,name=algethar_puzzle_box
  if I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 1"; end
  end
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
  -- thrash_cat,if=refreshable
  if S.Thrash:IsReady() and (Target:DebuffRefreshable(S.ThrashDebuff)) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash clearcasting 2"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>1
  if S.Swipe:IsReady() and (EnemiesCount11y > 1) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe clearcasting 4"; end
  end
  -- brutal_slash,if=spell_targets.brutal_slash>2&talent.moment_of_clarity.enabled
  if S.BrutalSlash:IsReady() and (EnemiesCount11y > 2 and S.MomentofClarity:IsAvailable()) then
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
  -- rake,target_if=max:ticks_gained_on_refresh,if=refreshable|(buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier&dot.rake.duration>6)
  if S.Rake:IsReady() then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeTicks, EvaluateTargetIfRake, not Target:IsInMeleeRange(8)) then return "rake builder 2"; end
  end
  -- moonfire_cat,target_if=refreshable
  if S.LIMoonfire:IsReady() then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfire, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat builder 4"; end
  end
  -- pool_resource,for_next=1
  -- thrash_cat,target_if=refreshable
  if S.Thrash:IsCastable() and (Target:DebuffRefreshable(S.ThrashDebuff)) then
    if CastPooling(S.Thrash, Player:EnergyTimeToX(40), not Target:IsInMeleeRange(11)) then return "thrash builder 6"; end
  end
  -- brutal_slash
  if S.BrutalSlash:IsReady() then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(11)) then return "brutal_slash builder 8"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>1
  if S.Swipe:IsReady() and (EnemiesCount11y > 1) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe builder 10"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred builder 12"; end
  end
end

local function BerserkBuilders()
  -- rake,target_if=refreshable
  if S.Rake:IsReady() then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateTargetIfFilterRake, not Target:IsInMeleeRange(8)) then return "rake berserk_builders 2"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>1
  if S.Swipe:IsReady() and (EnemiesCount11y > 1) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe berserk_builders 4"; end
  end
  -- shred,if=active_bt_triggers=2&buff.bt_shred.down
  if S.Shred:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.Shred)) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred berserk_builders 6"; end
  end
  -- brutal_slash,if=active_bt_triggers=2&buff.bt_brutal_slash.down
  if S.BrutalSlash:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.BrutalSlash)) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(11)) then return "brutal_slash berserk_builders 8"; end
  end
  -- moonfire_cat,target_if=refreshable
  if S.LIMoonfire:IsReady() then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfire, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat berserk_builders 10"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred berserk_builders 12"; end
  end
end

local function Finisher()
  -- primal_wrath,if=spell_targets.primal_wrath>2
  if S.PrimalWrath:IsReady() and (EnemiesCount11y > 2) then
    if Cast(S.PrimalWrath, nil, nil, not Target:IsInMeleeRange(11)) then return "primal_wrath finisher 2"; end
  end
  -- primal_wrath,target_if=refreshable,if=spell_targets.primal_wrath>1
  if S.PrimalWrath:IsReady() and (EnemiesCount11y > 1) then
    if Everyone.CastCycle(S.PrimalWrath, Enemies11y, EvaluateCyclePrimalWrath, not Target:IsInMeleeRange(11)) then return "primal_wrath finisher 4"; end
  end
  -- rip,target_if=refreshable
  if S.Rip:IsReady() then
    if Everyone.CastCycle(S.Rip, EnemiesMelee, EvaluateCycleRip, not Target:IsInRange(8)) then return "rip finisher 6"; end
  end
  -- pool_resource,for_next=1
  -- ferocious_bite,max_energy=1,if=!buff.bs_inc.up|(buff.bs_inc.up&!talent.soul_of_the_forest.enabled)
  if S.FerociousBite:IsReady() and (Player:BuffDown(BsInc) or (Player:BuffUp(BsInc) and not S.SouloftheForest:IsAvailable())) then
    if CastPooling(S.FerociousBite, Player:EnergyTimeToX(50)) then return "ferocious_bite finisher 8"; end
  end
  -- ferocious_bite,if=(buff.bs_inc.up&talent.soul_of_the_forest.enabled)
  if S.FerociousBite:IsReady() and (Player:BuffUp(BsInc) and S.SouloftheForest:IsAvailable()) then
    if Cast(S.FerociousBite, nil, nil, not Target:IsInMeleeRange(8)) then return "ferocious_bite finisher 10"; end
  end
end

local function Cooldown()
  -- incarnation
  if S.Incarnation:IsReady() then
    if Cast(S.Incarnation, Settings.Feral.GCDasOffGCD.BsInc) then return "incarnation cooldown 2"; end
  end
  -- berserk,if=!talent.convoke_the_spirits.enabled|talent.convoke_the_spirits.enabled&!(fight_remains<cooldown.convoke_the_spirits.remains)|talent.convoke_the_spirits.enabled&cooldown.convoke_the_spirits.remains<10|talent.convoke_the_spirits.enabled&fight_remains>120&cooldown.convoke_the_spirits.remains>25
  if S.Berserk:IsReady() and ((not S.ConvoketheSpirits:IsAvailable()) or S.ConvoketheSpirits:IsAvailable() and FightRemains >= S.ConvoketheSpirits:CooldownRemains() or S.ConvoketheSpirits:IsAvailable() and S.ConvoketheSpirits:CooldownRemains() < 10 or S.ConvoketheSpirits:IsAvailable() and FightRemains < 120 and S.ConvoketheSpirits:CooldownRemains() > 25) then
    if Cast(S.Berserk, Settings.Feral.GCDasOffGCD.BsInc) then return "berserk cooldown 4"; end
  end
  -- potion,if=buff.bs_inc.up|fight_remains<32|buff.tigers_fury.up&cooldown.convoke_the_spirits.up&talent.convoke_the_spirits.enabled&fight_remains<cooldown.bs_inc.remains
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(BsInc) or FightRemains < 32 or Player:BuffUp(S.TigersFury) and S.ConvoketheSpirits:CooldownUp() and S.ConvoketheSpirits:IsAvailable() and FightRemains < BsInc:CooldownRemains()) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldown 6"; end
    end
  end
  -- convoke_the_spirits,if=dot.rip.duration>5&(buff.tigers_fury.up&combo_points<4&cooldown.bs_inc.remains>20|fight_remains<5)
  if S.ConvoketheSpirits:IsReady() and (Target:DebuffRemains(S.RipDebuff) > 5 and (Player:BuffUp(S.TigersFury) and ComboPoints < 4 and BsInc:CooldownRemains() > 20 or FightRemains < 5)) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(8)) then return "convoke_the_spirits cooldown 8"; end
  end
  -- berserking,if=buff.bs_inc.up|fight_remains<15
  if S.Berserking:IsCastable() and (Player:BuffUp(BsInc) or FightRemains < 15) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cooldown 10"; end
  end
  -- shadowmeld,if=buff.tigers_fury.up&buff.bs_inc.down&combo_points<4&buff.sudden_ambush.down&dot.rake.pmultiplier<1.6&energy>40&druid.rake.ticks_gained_on_refresh>spell_targets.swipe_cat*2-2&target.time_to_die>5
  if S.Shadowmeld:IsCastable() and (Player:BuffUp(S.TigersFury) and Player:BuffDown(BsInc) and ComboPoints < 4 and Player:BuffDown(S.SuddenAmbushBuff) and Target:PMultiplier(S.Rake) < 1.6 and Player:Energy() > 40 and TicksGainedOnRefresh(S.RakeDebuff) > EnemiesCount11y * 2 - 2 and Target:TimeToDie() > 5) then
    if Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "shadowmeld cooldown 12"; end
  end
  -- use_item,name=manic_grieftorch,if=energy.deficit>40
  if I.ManicGrieftorch:IsEquippedAndReady() and (Player:EnergyDeficit() > 40) then
    if Cast(I.ManicGrieftorch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "manic_grieftorch cooldown 14"; end
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
    -- sunfire,line_cd=4*gcd
    if S.Sunfire:IsReady() and (S.Sunfire:TimeSinceLastCast() > 4 * Player:GCD()) then
      if Cast(S.Sunfire, nil, nil, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire owlweaving 2"; end
    end
  end
  -- Manually added: moonkin_form,if=!buff.moonkin_form.up
  if S.MoonkinForm:IsCastable() and (Player:BuffDown(S.MoonkinForm)) then
    if Cast(S.MoonkinForm) then return "moonkin_form owlweave 4"; end
  end
end

local function Bloodtalons()
  -- rake,target_if=max:druid.rake.ticks_gained_on_refresh,if=(refreshable|1.4*persistent_multiplier>dot.rake.pmultiplier)&buff.bt_rake.down
  if S.Rake:IsReady() and (BTBuffDown(S.Rake)) then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeTicks, EvaluateTargetIfRakeBloodtalons, not Target:IsInRange(8)) then return "rake bloodtalons 2"; end
  end
  -- shred,if=buff.bt_shred.down&buff.clearcasting.up&spell_targets.swipe_cat=1
  if S.Shred:IsReady() and (BTBuffDown(S.Shred) and Player:BuffUp(S.Clearcasting) and EnemiesCount11y == 1) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred bloodtalons 4"; end
  end
  -- lunar_inspiration,if=refreshable&buff.bt_moonfire.down
  if S.LunarInspiration:IsAvailable() and S.LIMoonfire:IsReady() and (Target:DebuffRefreshable(S.LIMoonfireDebuff) and BTBuffDown(S.LIMoonfire)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire bloodtalons 6"; end
  end
  -- shred,if=buff.bt_shred.down
  if S.Shred:IsReady() and (BTBuffDown(S.Shred)) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred bloodtalons 8"; end
  end
  -- thrash_cat,target_if=refreshable&buff.bt_thrash.down
  if S.Thrash:IsReady() and (BTBuffDown(S.Thrash)) then
    if Everyone.CastCycle(S.Thrash, Enemies11y, EvaluateCycleThrash, not Target:IsInMeleeRange(8)) then return "thrash bloodtalons 10"; end
  end
  -- brutal_slash,if=buff.bt_brutal_slash.down
  if S.BrutalSlash:IsReady() and (BTBuffDown(S.BrutalSlash)) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(8)) then return "brutal_slash bloodtalons 12"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>1&buff.bt_swipe.down
  if S.Swipe:IsReady() and (EnemiesCount11y > 1 and BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bloodtalons 14"; end
  end
  -- swipe_cat,if=buff.bt_swipe.down
  if S.Swipe:IsReady() and (BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bloodtalons 16"; end
  end
  -- thrash_cat,if=buff.bt_thrash.down
  if S.Thrash:IsReady() and (BTBuffDown(S.Thrash)) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bloodtalons 18"; end
  end
  -- rake,if=buff.bt_rake.down&combo_points>4
  if S.Rake:IsReady() and (BTBuffDown(S.Rake) and ComboPoints > 4) then
    if Cast(S.Rake, nil, nil, not Target:IsInMeleeRange(8)) then return "rake bloodtalons 20"; end
  end
end

local function BloodtalonsAoE()
  -- rake,target_if=max:druid.rake.ticks_gained_on_refresh,if=(refreshable|1.4*persistent_multiplier>dot.rake.pmultiplier)&buff.bt_rake.down
  if S.Rake:IsReady() then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeTicks, EvaluateTargetIfRakeBloodtalons, not Target:IsInRange(8)) then return "rake bloodtalons_aoe 2"; end
  end
  -- lunar_inspiration,if=refreshable&buff.bt_moonfire.down
  if S.LunarInspiration:IsAvailable() and S.LIMoonfire:IsReady() and (Target:DebuffRefreshable(S.LIMoonfireDebuff) and BTBuffDown(S.LIMoonfire)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire bloodtalons_aoe 4"; end
  end
  -- shred,if=buff.bt_shred.down&buff.clearcasting.up&spell_targets.swipe_cat=1
  if S.Shred:IsReady() and (BTBuffDown(S.Shred) and Player:BuffUp(S.Clearcasting) and EnemiesCount11y == 1) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred bloodtalons_aoe 6"; end
  end
  -- brutal_slash,if=buff.bt_brutal_slash.down
  if S.BrutalSlash:IsReady() and (BTBuffDown(S.BrutalSlash)) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(8)) then return "brutal_slash bloodtalons_aoe 8"; end
  end
  -- thrash_cat,target_if=refreshable&buff.bt_thrash.down
  if S.Thrash:IsReady() and (BTBuffDown(S.Thrash)) then
    if Everyone.CastCycle(S.Thrash, Enemies11y, EvaluateCycleThrash, not Target:IsInMeleeRange(8)) then return "thrash bloodtalons_aoe 10"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>1&buff.bt_swipe.down
  if S.Swipe:IsReady() and (EnemiesCount11y > 1 and BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bloodtalons_aoe 12"; end
  end
  -- shred,if=buff.bt_shred.down
  if S.Shred:IsReady() and (BTBuffDown(S.Shred)) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred bloodtalons_aoe 14"; end
  end
  -- swipe_cat,if=buff.bt_swipe.down
  if S.Swipe:IsReady() and (BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(8)) then return "swipe bloodtalons_aoe 16"; end
  end
  -- thrash_cat,if=buff.bt_thrash.down
  if S.Thrash:IsReady() and (BTBuffDown(S.Thrash)) then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(8)) then return "thrash bloodtalons_aoe 18"; end
  end
  -- rake,if=buff.bt_rake.down&combo_points>4
  if S.Rake:IsReady() and (BTBuffDown(S.Rake) and ComboPoints > 4) then
    if Cast(S.Rake, nil, nil, not Target:IsInMeleeRange(8)) then return "rake bloodtalons_aoe 20"; end
  end
end

local function Aoe()
  -- pool_resource,for_next=1
  -- primal_wrath,if=combo_points>3
  if S.PrimalWrath:IsCastable() and (ComboPoints > 3) then
    if CastPooling(S.PrimalWrath, Player:EnergyTimeToX(20), not Target:IsInMeleeRange(11)) then return "primal_wrath aoe 2"; end
  end
  -- ferocious_bite,if=buff.apex_predators_craving.up&(!buff.sabertooth.up|(!buff.bloodtalons.stack=1))
  if S.FerociousBite:IsReady() and (Player:BuffUp(S.ApexPredatorsCravingBuff) and (Player:BuffDown(S.SabertoothBuff) or Player:BuffStack(S.BloodtalonsBuff) ~= 1)) then
    if Cast(S.FerociousBite, nil, nil, not Target:IsInMeleeRange(8)) then return "ferocious_bite aoe 4"; end
  end
  -- run_action_list,name=bloodtalons_aoe,if=variable.need_bt&active_bt_triggers>=1
  if (VarNeedBT and CountActiveBtTriggers() >= 1) then
    local ShouldReturn = BloodtalonsAoE(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Bloodtalons()"; end
  end
  -- pool_resource,for_next=1
  -- thrash_cat,target_if=refreshable
  if S.Thrash:IsCastable() and (Target:DebuffRefreshable(S.ThrashDebuff)) then
    if CastPooling(S.Thrash, Player:EnergyTimeToX(40), not Target:IsInMeleeRange(11)) then return "thrash aoe 6"; end
  end
  -- brutal_slash
  if S.BrutalSlash:IsReady() then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInMeleeRange(11)) then return "brutal_slash aoe 8"; end
  end
  -- pool_resource,for_next=1
  -- rake,target_if=max:dot.rake.ticks_gained_on_refresh.pmult,if=((dot.rake.ticks_gained_on_refresh.pmult*(1+talent.doubleclawed_rake.enabled))>(spell_targets.swipe_cat*0.216+3.32))
  if S.Rake:IsReady() then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeAoe, EvaluateTargetIfRakeAoe, not Target:IsInMeleeRange(8)) then return "rake aoe 10"; end
  end
  -- lunar_inspiration,target_if=max:((ticks_gained_on_refresh+1)-(spell_targets.swipe_cat*2.492))
  if S.LIMoonfire:IsCastable() then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfireAoe, not Target:IsSpellInRange(S.LIMoonfire)) then return "lunar_inspiration aoe 12"; end
  end
  -- swipe_cat
  if S.Swipe:IsReady() then
    if Cast(S.Swipe, nil, nil, not Target:IsInMeleeRange(11)) then return "swipe aoe 14"; end
  end
  -- shred,if=action.shred.damage>action.thrash_cat.damage
  if S.Shred:IsReady() and (S.Shred:Damage() > S.Thrash:Damage()) then
    if Cast(S.Shred, nil, nil, not Target:IsInMeleeRange(8)) then return "shred aoe 16"; end
  end
  -- thrash_cat
  if S.Thrash:IsReady() then
    if Cast(S.Thrash, nil, nil, not Target:IsInMeleeRange(11)) then return "thrash aoe 18"; end
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
    -- prowl,if=buff.bs_inc.down
    if S.Prowl:IsCastable() and (Player:BuffDown(BsInc)) then
      if Cast(S.Prowl) then return "prowl main 2"; end
    end
    -- invoke_external_buff,name=power_infusion,if=buff.bs_inc.up|fight_remains<cooldown.bs_inc.remains
    -- Note: We're not handling external buffs
    -- variable,name=need_bt,value=talent.bloodtalons.enabled&buff.bloodtalons.down
    VarNeedBT = (S.Bloodtalons:IsAvailable() and Player:BuffDown(S.BloodtalonsBuff))
    -- tigers_fury
    if S.TigersFury:IsCastable() and CDsON() then
      if Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury main 4"; end
    end
    -- rake,if=buff.prowl.up|buff.shadowmeld.up
    if S.Rake:IsReady() and (Player:StealthUp(false, true)) then
      if Cast(S.Rake, nil, nil, not Target:IsInMeleeRange(8)) then return "rake main 6"; end
    end
    -- cat_form,if=!buff.cat_form.up
    if S.CatForm:IsCastable() then
      if Cast(S.CatForm) then return "cat_form main 8"; end
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
    -- feral_frenzy,if=combo_points<2|combo_points=2&buff.bs_inc.up
    if S.FeralFrenzy:IsReady() and (ComboPoints < 2 or ComboPoints == 2 and Player:BuffUp(BsInc)) then
      if Cast(S.FeralFrenzy, nil, nil, not Target:IsInMeleeRange(8)) then return "feral_frenzy main 12"; end
    end
    -- run_action_list,name=aoe,if=spell_targets.swipe_cat>1&talent.primal_wrath.enabled
    if (EnemiesCount11y > 1 and S.PrimalWrath:IsAvailable()) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Aoe()"; end
    end
    -- ferocious_bite,if=buff.apex_predators_craving.up
    if S.FerociousBite:IsReady() and (Player:BuffUp(S.ApexPredatorsCravingBuff)) then
      if Cast(S.FerociousBite, nil, nil, not Target:IsInMeleeRange(8)) then return "ferocious_bite main 10"; end
    end
    -- call_action_list,name=bloodtalons,if=variable.need_bt&!buff.bs_inc.up
    if (VarNeedBT and Player:BuffDown(BsInc)) then
      local ShouldReturn = Bloodtalons(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=finisher,if=(combo_points>3&talent.lions_strength.enabled)|combo_points=5&!talent.lions_strength.enabled
    if (ComboPoints > 3 and S.LionsStrength:IsAvailable()) or ComboPoints == 5 then
      local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=berserk_builders,if=combo_points<5&buff.bs_inc.up
    if (ComboPoints < 5 and Player:BuffUp(BsInc)) then
      local ShouldReturn = BerserkBuilders(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=builder,if=combo_points<5
    if (ComboPoints < 5) then
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
