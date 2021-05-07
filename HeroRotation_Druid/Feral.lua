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
local VarFourCPBite
local VarFiller
local VarRipTicks
local VarShortestTTD
local ComboPoints, ComboPointsDeficit
local FightRemains

-- Enemy Variables
local EnemiesMelee, EnemiesCountMelee
local Enemies8y, EnemiesCount8y
local MeleeRange = S.BalanceAffinity:IsAvailable() and 8 or 5
local EightRange = S.BalanceAffinity:IsAvailable() and 11 or 8
local InterruptRange = S.BalanceAffinity:IsAvailable() and 16 or 13
local FortyRange = S.BalanceAffinity:IsAvailable() and 43 or 40

-- Berserk/Incarnation Variables
local BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk

-- Legendaries
local DeepFocusEquipped = Player:HasLegendaryEquipped(46)
local CateyeCurioEquipped = Player:HasLegendaryEquipped(57)

-- Event Registration
HL:RegisterForEvent(function()
  DeepFocusEquipped = Player:HasLegendaryEquipped(46)
  CateyeCurioEquipped = Player:HasLegendaryEquipped(57)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  MeleeRange = S.BalanceAffinity:IsAvailable() and 8 or 5
  EightRange = S.BalanceAffinity:IsAvailable() and 11 or 8
  InterruptRange = S.BalanceAffinity:IsAvailable() and 16 or 13
  FortyRange = S.BalanceAffinity:IsAvailable() and 43 or 40
  BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk
end, "PLAYER_TALENT_UPDATE")

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
S.Rip:RegisterPMultiplier({S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15})
S.Rake:RegisterPMultiplier(S.RakeDebuff, ComputeRakePMultiplier)

local function SwipeBleedMult()
  return (Target:DebuffUp(S.RipDebuff) or Target:DebuffUp(S.RakeDebuff) or Target:DebuffUp(S.ThrashCatDebuff)) and 1.2 or 1;
end

S.Shred:RegisterDamageFormula(
  function()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() *
      -- Shred Modifier
      0.46 *
      -- Bleeding Bonus
      SwipeBleedMult() *
      -- Stealth Modifier
      (Player:StealthUp(true) and 1.6 or 1) *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
)

S.BrutalSlash:RegisterDamageFormula(
  function()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() *
      -- Brutal Slash Modifier
      0.69 *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
)

-- Functions for Bloodtalons
local BtTriggers = {
  S.Rake,
  S.Moonfire,
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

local function TicksGainedOnRefresh(Spell, mod, TargetUnit)
  -- mod used for Primal Wrath, which gives half the duration of a Rip
  if not mod then mod = 1 end
  -- TargetUnit used for Primal Wrath, since it's AoE
  if not TargetUnit then TargetUnit = Target end

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

  local OldTicks = TargetUnit:DebuffTicksRemain(Spell)
  local OldTime = TargetUnit:DebuffRemains(Spell)
  local NewTime = AddedDuration + OldTime
  if NewTime > MaxDuration then NewTime = MaxDuration end
  local NewTicks = NewTime / TickTime
  return NewTicks - OldTicks
end

local function PrimalWrathTicksGainedOnRefresh()
  local AddedTicks = 0
  for _, TargetUnit in pairs(Enemies8y) do
    AddedTicks = AddedTicks + TicksGainedOnRefresh(S.RipDebuff, 0.5, TargetUnit)
  end
  return AddedTicks
end

-- CastCycle/CastTargetIf Functions
local function EvaluateCycleRakeMain14(TargetUnit)
  -- target_if=(refreshable|persistent_multiplier>dot.rake.pmultiplier)&druid.rake.ticks_gained_on_refresh>spell_targets.swipe_cat*2-2
  return ((TargetUnit:DebuffRefreshable(S.RakeDebuff) or Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake)) and TicksGainedOnRefresh(S.RakeDebuff) > EnemiesCount8y * 2 - 2)
end

local function EvaluateCycleMoonfireMain16(TargetUnit)
  -- target_if=refreshable&druid.lunar_inspiration.ticks_gained_on_refresh>spell_targets.swipe_cat*2-2
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TicksGainedOnRefresh(S.MoonfireDebuff) > EnemiesCount8y * 2 - 2)
end

local function EvaluateCycleRakeStealth2(TargetUnit)
  -- target_if=(dot.rake.pmultiplier<1.5|refreshable)&druid.rake.ticks_gained_on_refresh>2|buff.bs_inc.remains<1
  return ((TargetUnit:PMultiplier(S.Rake) < 1.5 or TargetUnit:DebuffRefreshable(S.RakeDebuff)) and TicksGainedOnRefresh(S.RakeDebuff) > 2 or Player:BuffRemains(BsInc) < 1)
end

local function EvaluateCycleRakeBloodtalons2(TargetUnit)
  -- target_if=(!ticking|(refreshable&persistent_multiplier>dot.rake.pmultiplier)|(active_bt_triggers=2&persistent_multiplier>dot.rake.pmultiplier)|(active_bt_triggers=2&refreshable))&buff.bt_rake.down&druid.rake.ticks_gained_on_refresh>=2
  return ((TargetUnit:DebuffDown(S.RakeDebuff) or (TargetUnit:DebuffRefreshable(S.RakeDebuff) and Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake)) or (CountActiveBtTriggers() == 2 and Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake)) or (CountActiveBtTriggers() == 2 and TargetUnit:DebuffRefreshable(S.RakeDebuff))) and TicksGainedOnRefresh(S.RakeDebuff) >= 2)
end

local function EvaluateCycleMoonfireBloodtalons4(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff))
end

local function EvaluateCycleThrashBloodtalons6(TargetUnit)
  -- target_if=refreshable&buff.bt_thrash.down&druid.thrash_cat.ticks_gained_on_refresh>(4+spell_targets.thrash_cat*4)%(1+mastery_value)-conduit.taste_for_blood.enabled
  return (TargetUnit:DebuffRefreshable(S.ThrashDebuff) and TicksGainedOnRefresh(S.ThrashDebuff) > (4 + EnemiesCount8y * 4) / (1 + (Player:MasteryPct() / 100)) - num(S.TasteForBlood:ConduitEnabled()))
end

local function EvaluateCycleAdaptiveSwarmCooldown2(TargetUnit)
  -- target_if=((!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&(dot.adaptive_swarm_damage.stack<3|!dot.adaptive_swarm_heal.stack>1)&!action.adaptive_swarm_heal.in_flight&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight)&target.time_to_die>5|active_enemies>2&!dot.adaptive_swarm_damage.ticking&energy<35&target.time_to_die>5
  return (((TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) or TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 2) and (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 or not Player:BuffStack(S.AdaptiveSwarmHeal) > 1) and not S.AdaptiveSwarm:InFlight()) and TargetUnit:TimeToDie() > 5 or EnemiesCount8y > 2 and TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) and Player:Energy() < 35 and Target:TimeToDie() > 5)
end

local function EvaluateCycleRipFinisher6(TargetUnit)
  -- target_if=refreshable&druid.rip.ticks_gained_on_refresh>variable.rip_ticks&((buff.tigers_fury.up|cooldown.tigers_fury.remains>5)&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&dot.rip.pmultiplier<=persistent_multiplier|!talent.sabertooth.enabled)
  return (TargetUnit:DebuffRefreshable(S.RipDebuff) and TicksGainedOnRefresh(S.RipDebuff) > VarRipTicks and ((Player:BuffUp(S.TigersFury) or S.TigersFury:CooldownRemains() > 5) and (Player:BuffUp(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable()) and Target:PMultiplier(S.Rip) <= Player:PMultiplier(S.Rip) or not S.Sabertooth:IsAvailable()))
end

local function EvaluateCycleRakeFiller2(TargetUnit)
  -- target_if=variable.filler=1&dot.rake.pmultiplier<=persistent_multiplier
  return (VarFiller == "Rake Non-Snapshot" and TargetUnit:PMultiplier(S.Rake) <= Player:PMultiplier(S.Rake))
end

local function EvaluateTargetIfFilterTTD(TargetUnit)
  -- target_if=max:target.time_to_die
  return (TargetUnit:TimeToDie())
end

local function EvaluateTargetIfFerociousBiteMain12(TargetUnit)
  -- if=buff.apex_predators_craving.up
  return (Player:BuffUp(S.ApexPredatorsCravingBuff))
end

local function EvaluateTargetIfFeralFrenzyCooldown4(TargetUnit)
  -- if=combo_points<3&target.time_to_die>7&!cooldown.tigers_fury.up|fight_remains<8&fight_remains>2
  return (ComboPoints < 3 and TargetUnit:TimeToDie() > 7 and not S.TigersFury:CooldownUp() or fightRemains < 8 and FightRemains > 2)
end

local function EvaluateTargetIfDummy(TargetUnit)
  return true
end

-- APL Functions
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=4cp_bite,value=0
  VarFourCPBite = 0
  -- variable,name=filler,value=0
  VarFiller = Settings.Feral.FillerSpell
  -- variable,name=rip_ticks,value=7
  VarRipTicks = 7
  if Everyone.TargetIsValid() then
    -- cat_form
    if S.CatForm:IsCastable() then
      if Cast(S.CatForm) then return "cat_form precombat 2"; end
    end
    -- prowl
    if S.Prowl:IsCastable() then
      if Cast(S.Prowl) then return "prowl precombat 4"; end
    end
    -- Manually added: wild_charge if talented and not in melee range
    if S.WildCharge:IsCastable() and not Target:IsInRange(MeleeRange) then
      if Cast(S.WildCharge, nil, nil, not Target:IsSpellInRange(S.WildCharge)) then return "wild_charge precombat 6"; end
    end
    -- Manually added: rake if in melee range
    if S.Rake:IsReady() and Target:IsInRange(MeleeRange) then
      if Cast(S.Rake, nil, nil, not Target:IsInRange(MeleeRange)) then return "rake precombat 8"; end
    end
  end
end

local function Owlweave()
  if (Player:BuffUp(S.MoonkinForm)) then
    -- starsurge,if=buff.heart_of_the_wild.up
    if S.Starsurge:IsReady() and (Player:BuffUp(S.HeartoftheWildBuff)) then
      if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge owlweave 2"; end
    end
    -- sunfire,line_cd=4*gcd
    if S.Sunfire:IsReady() and (S.Sunfire:TimeSinceLastCast() > 4 * Player:GCD()) then
      if Cast(S.Sunfire, nil, nil, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire owlweave 4"; end
    end
    -- moonfire,line_cd=4*gcd,if=buff.moonkin_form.up&(runeforge.cateye_curio|runeforge.draught_of_deep_focus)&spell_targets.thrash_cat<2&!talent.lunar_inspiration.enabled
    if S.Moonfire:IsReady() and S.Moonfire:TimeSinceLastCast() > 4 * Player:GCD() and ((CateyeCurioEquipped or DeepFocusEquipped) and EnemiesCount8y < 2 and not S.LunarInspiration:IsAvailable()) then
      if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire owlweave 6"; end
    end
  end
  -- heart_of_the_wild,if=energy<30&dot.rip.remains>4.5&(cooldown.tigers_fury.remains>=6.5|runeforge.cateye_curio)&buff.clearcasting.stack<1&!buff.apex_predators_craving.up&!buff.bloodlust.up&!buff.bs_inc.up&(cooldown.convoke_the_spirits.remains>6.5|!covenant.night_fae)&(!covenant.necrolord|cooldown.adaptive_swarm.remains>=5|dot.adaptive_swarm_damage.remains>7)
  if S.HeartoftheWild:IsCastable() and (Player:Energy() < 30 and Target:DebuffRemains(S.RipDebuff) > 4.5 and (S.TigersFury:CooldownRemains() >= 6.5 or CateyeCurioEquipped) and Player:BuffDown(S.Clearcasting) and Player:BuffDown(S.ApexPredatorsCravingBuff) and Player:BloodlustDown() and Player:BuffDown(BsInc) and (S.ConvoketheSpirits:CooldownRemains() > 6.5 or Player:Covenant() ~= "Night Fae") and (Player:Covenant() ~= "Necrolord" or S.AdaptiveSwarm:CooldownRemains() >= 5 or Target:DebuffRemains(S.AdaptiveSwarmDebuff) > 7)) then
    if Cast(S.HeartoftheWild) then return "heart_of_the_wild owlweave 8"; end
  end
  -- moonkin_form,if=energy<30&dot.rip.remains>4.5&(cooldown.tigers_fury.remains>=4.5|runeforge.cateye_curio)&buff.clearcasting.stack<1&!buff.apex_predators_craving.up&!buff.bloodlust.up&!buff.bs_inc.up&(cooldown.convoke_the_spirits.remains>6.5|!covenant.night_fae)&(!covenant.necrolord|cooldown.adaptive_swarm.remains>=5|dot.adaptive_swarm_damage.remains>7)
  if S.MoonkinForm:IsCastable() and (Player:Energy() < 30 and Target:DebuffRemains(S.RipDebuff) > 4.5 and (S.TigersFury:CooldownRemains() >= 4.5 or CateyeCurioEquipped) and Player:BuffDown(S.Clearcasting) and Player:BuffDown(S.ApexPredatorsCravingBuff) and Player:BloodlustDown() and Player:BuffDown(BsInc) and (S.ConvoketheSpirits:CooldownRemains() > 6.5 or Player:Covenant() ~= "Night Fae") and (Player:Covenant() ~= "Necrolord" or S.AdaptiveSwarm:CooldownRemains() >= 5 or Target:DebuffRemains(S.AdaptiveSwarmDebuff) > 7)) then
    if Cast(S.MoonkinForm) then return "moonkin_form owlweave 10"; end
  end
end

local function Stealth()
  -- pool_resource,for_next=1
  -- rake,target_if=(dot.rake.pmultiplier<1.5|refreshable)&druid.rake.ticks_gained_on_refresh>2|buff.bs_inc.remains<1
  if S.Rake:IsCastable() and ((Player:PMultiplier(S.Rake) < 1.5 or Target:DebuffRefreshable(S.RakeDebuff)) and TicksGainedOnRefresh(S.RakeDebuff) > 2 or Player:BuffRemains(BsInc) < 1) then
    if Player:Energy() >= 35 then
      if Cast(S.Rake, nil, nil, not Target:IsInRange(MeleeRange)) then return "rake target stealth 2"; end
    else
      if CastPooling(S.Rake, Player:EnergyTimeToX(35)) then return "Pool for rake target stealth 2"; end
    end
  end
  if S.Rake:IsCastable() and AoEON() then
    for _, CycleUnit in pairs(Enemies8y) do
      if CycleUnit:GUID() ~= Target:GUID() and not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and EvaluateCycleRakeStealth2(CycleUnit) then
        if Player:Energy() >= 35 then
          if HR.CastLeftNameplate(CycleUnit, S.Rake) then return "rake off-target stealth 2"; end
        else
          if CastPooling(S.Pool, Player:EnergyTimeToX(35)) then return "Pool for rake off-target stealth 2"; end
        end
      end
    end
  end
  -- lunar_inspiration,if=spell_targets.thrash_cat<3&refreshable&druid.lunar_inspiration.ticks_gained_on_refresh>5&(combo_points=4|dot.lunar_inspiration.remains<5|!dot.lunar_inspiration.ticking)
  if S.LunarInspiration:IsAvailable() and S.Moonfire:IsReady() and (EnemiesCount8y < 3 and Target:DebuffRefreshable(S.MoonfireDebuff) and TicksGainedOnRefresh(S.MoonfireDebuff) > 5 and (ComboPoints == 4 or Target:DebuffRemains(S.MoonfireDebuff) < 5 or Target:DebuffDown(S.MoonfireDebuff))) then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire stealth 4"; end
  end
  -- brutal_slash,if=spell_targets.brutal_slash>2
  if S.BrutalSlash:IsReady() and (EnemiesCount8y > 2) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInRange(EightRange)) then return "brutal_slash stealth 6"; end
  end
  -- pool_resource,for_next=1
  -- shred,if=combo_points<4&spell_targets.thrash_cat<5
  if S.Shred:IsCastable() and (ComboPoints < 4 and EnemiesCount8y < 5) then
    if CastPooling(S.Shred, Player:EnergyTimeToX(40), not Target:IsInRange(MeleeRange)) then return "shred stealth 8"; end
  end
end

local function Bloodtalons()
  -- rake,target_if=(!ticking|(refreshable&persistent_multiplier>dot.rake.pmultiplier)|(active_bt_triggers=2&persistent_multiplier>dot.rake.pmultiplier)|(active_bt_triggers=2&refreshable))&buff.bt_rake.down&druid.rake.ticks_gained_on_refresh>=2
  if S.Rake:IsReady() and (BTBuffDown(S.Rake)) then
    if Everyone.CastCycle(S.Rake, Enemies8y, EvaluateCycleRakeBloodtalons2, not Target:IsInRange(EightRange)) then return "rake bloodtalons 2"; end
  end
  -- lunar_inspiration,target_if=refreshable&buff.bt_moonfire.down
  if S.LunarInspiration:IsAvailable() and S.Moonfire:IsReady() and (BTBuffDown(S.Moonfire)) then
    if Everyone.CastCycle(S.Moonfire, Enemies8y, EvaluateCycleMoonfireBloodtalons4, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire bloodtalons 4"; end
  end
  -- thrash_cat,target_if=refreshable&buff.bt_thrash.down&druid.thrash_cat.ticks_gained_on_refresh>(4+spell_targets.thrash_cat*4)%(1+mastery_value)-conduit.taste_for_blood.enabled
  if S.Thrash:IsReady() and (BTBuffDown(S.Thrash)) then
    if Everyone.CastCycle(S.Thrash, Enemies8y, EvaluateCycleThrashBloodtalons6, not Target:IsInRange(EightRange)) then return "thrash bloodtalons 6"; end
  end
  -- brutal_slash,if=buff.bt_brutal_slash.down
  if S.BrutalSlash:IsReady() and (BTBuffDown(S.BrutalSlash)) then
    if Cast(S.BrutalSlash, nil, nil, not Target:IsInRange(EightRange)) then return "brutal_slash bloodtalons 8"; end
  end
  -- swipe_cat,if=buff.bt_swipe.down&spell_targets.swipe_cat>1
  if S.Swipe:IsReady() and (BTBuffDown(S.Swipe) and EnemiesCount8y > 1) then
    if Cast(S.Swipe, nil, nil, not Target:IsInRange(EightRange)) then return "swipe bloodtalons 10"; end
  end
  -- shred,if=buff.bt_shred.down
  if S.Shred:IsReady() and (BTBuffDown(S.Shred)) then
    if Cast(S.Shred, nil, nil, not Target:IsInRange(MeleeRange)) then return "shred bloodtalons 12"; end
  end
  -- swipe_cat,if=buff.bt_swipe.down
  if S.Swipe:IsReady() and (BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not Target:IsInRange(EightRange)) then return "swipe bloodtalons 14"; end
  end
  -- thrash_cat,if=buff.bt_thrash.down
  if S.Thrash:IsReady() and (BTBuffDown(S.Thrash)) then
    if Cast(S.Thrash, nil, nil, not Target:IsInRange(EightRange)) then return "thrash bloodtalons 16"; end
  end
end

local function Cooldown()
  -- adaptive_swarm,target_if=((!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&(dot.adaptive_swarm_damage.stack<3|!dot.adaptive_swarm_heal.stack>1)&!action.adaptive_swarm_heal.in_flight&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight)&target.time_to_die>5|active_enemies>2&!dot.adaptive_swarm_damage.ticking&energy<35&target.time_to_die>5
  if S.AdaptiveSwarm:IsCastable() then
    if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8y, EvaluateCycleAdaptiveSwarmCooldown2, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.Commons.DisplayStyle.Covenant) then return "adaptive_swarm cooldown 2"; end
  end
  -- feral_frenzy,target_if=max:target.time_to_die,if=combo_points<3&target.time_to_die>7&!cooldown.tigers_fury.up|fight_remains<8&fight_remains>2
  if S.FeralFrenzy:IsReady() then
    if Everyone.CastTargetIf(S.FeralFrenzy, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfFeralFrenzyCooldown4, not Target:IsInRange(MeleeRange)) then return "feral_frenzy cooldown 4"; end
  end
  -- berserk,if=combo_points>=3
  -- incarnation,if=combo_points>=3
  if BsInc:IsReady() and (ComboPoints >= 3) then
    if Cast(BsInc, Settings.Feral.GCDasOffGCD.BsInc) then return "bs_inc cooldown 6"; end
  end
  -- tigers_fury,if=energy.deficit>40|buff.bs_inc.up|(talent.predator.enabled&variable.shortest_ttd<3)
  if S.TigersFury:IsCastable() and (Player:EnergyDeficit() > 40 or Player:BuffUp(BsInc) or (S.Predator:IsAvailable() and VarShortestTTD < 3)) then
    if Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury cooldown 8"; end
  end
  -- shadowmeld,if=buff.tigers_fury.up&buff.bs_inc.down&combo_points<4&dot.rake.pmultiplier<1.6&energy>40&druid.rake.ticks_gained_on_refresh>spell_targets.swipe_cat*2-2&target.time_to_die>5
  if S.Shadowmeld:IsCastable() and (Player:BuffUp(S.TigersFury) and Player:BuffDown(BsInc) and ComboPoints < 4 and Target:PMultiplier(S.Rake) < 1.6 and Player:Energy() > 40 and TicksGainedOnRefresh(S.RakeDebuff) > EnemiesCount8y * 2 - 2 and Target:TimeToDie() > 5) then
    if Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "shadowmeld cooldown 10"; end
  end
  -- berserking,if=buff.tigers_fury.up|buff.bs_inc.up
  if S.Berserking:IsCastable() and (Player:BuffUp(S.TigersFury) or Player:BuffUp(BsInc)) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cooldown 12"; end
  end
  -- potion,if=buff.bs_inc.up
  if I.PotionofSpectralAgility:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(BsInc)) then
    if Cast(I.PotionofSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldown 14"; end
  end
  -- ravenous_frenzy,if=buff.bs_inc.up|fight_remains<21
  if S.RavenousFrenzy:IsCastable() and (Player:BuffUp(BsInc) or FightRemains < 21) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant) then return "ravenous_frenzy cooldown 16"; end
  end
  -- convoke_the_spirits,if=(dot.rip.remains>4&combo_points<3&dot.rake.ticking&energy.deficit>=20)|fight_remains<5
  if S.ConvoketheSpirits:IsCastable() and ((Target:DebuffRemains(S.RipDebuff) > 4 and ComboPoints < 3 and Target:DebuffUp(S.RakeDebuff) and Player:EnergyDeficit() >= 20) or FightRemains < 5) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "convoke_the_spirits cooldown 18"; end
  end
  -- kindred_spirits,if=buff.tigers_fury.up|(conduit.deep_allegiance.enabled)
  if S.KindredSpirits:IsCastable() and (Player:BuffUp(S.TigersFury) or S.DeepAllegiance:ConduitEnabled()) then
    if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "kindred_spirits cooldown 20"; end
  end
  -- use_items
  if (Settings.Commons.Enabled.Trinkets) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function Finisher()
  -- savage_roar,if=buff.savage_roar.remains<3
  if S.SavageRoar:IsReady() and (Player:BuffRemains(S.SavageRoar) < 3) then
    if Cast(S.SavageRoar) then return "savage_roar finisher 2"; end
  end
  -- primal_wrath,if=(druid.primal_wrath.ticks_gained_on_refresh>3*(spell_targets.primal_wrath+1)&spell_targets.primal_wrath>1)|spell_targets.primal_wrath>(3+1*talent.sabertooth.enabled)
  if S.PrimalWrath:IsReady() and ((PrimalWrathTicksGainedOnRefresh() > 3 * (EnemiesCount8y + 1) and EnemiesCount8y > 1) or EnemiesCount8y > (3 + 1 * num(S.Sabertooth:IsAvailable()))) then
    if Cast(S.PrimalWrath, nil, nil, not Target:IsInRange(EightRange)) then return "primal_wrath finisher 4"; end
  end
  -- rip,target_if=refreshable&druid.rip.ticks_gained_on_refresh>variable.rip_ticks&((buff.tigers_fury.up|cooldown.tigers_fury.remains>5)&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&dot.rip.pmultiplier<=persistent_multiplier|!talent.sabertooth.enabled)
  if S.Rip:IsReady() then
    if Everyone.CastCycle(S.Rip, EnemiesMelee, EvaluateCycleRipFinisher6, not Target:IsInRange(MeleeRange)) then return "rip finisher 6"; end
  end
  -- savage_roar,if=buff.savage_roar.remains<(combo_points+1)*6*0.3
  if S.SavageRoar:IsReady() and (Player:BuffRemains(S.SavageRoar) < (ComboPoints + 1) * 6 * 0.3) then
    if Cast(S.SavageRoar) then return "savage_roar finisher 8"; end
  end
  -- ferocious_bite,max_energy=1,target_if=max:time_to_die
  if S.FerociousBite:IsReady() and Player:Energy() >= 50 then
    if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfDummy, not Target:IsInRange(MeleeRange)) then return "ferocious_bite max_energy finisher 10"; end
  end
  -- ferocious_bite,target_if=max:time_to_die,if=buff.bs_inc.up&talent.soul_of_the_forest.enabled
  if S.FerociousBite:IsReady() and (Player:BuffUp(BsInc) and S.SouloftheForest:IsAvailable()) then
    if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfDummy, not Target:IsInRange(MeleeRange)) then return "ferocious_bite finisher 12"; end
  end
  -- Manually added the below two lines, as otherwise the addon was wasting CPs
  -- Sim showed nearly identical results
  -- pool_resource,for_next=1
  -- ferocious_bite,max_energy=1
  if S.FerociousBite:IsReady() then
    if CastPooling(S.FerociousBite, Player:EnergyTimeToX(50)) then return "ferocious_bite finisher 14"; end
  end
end

local function Filler()
  -- rake,target_if=variable.filler=1&dot.rake.pmultiplier<=persistent_multiplier
  if S.Rake:IsReady() then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRakeFiller2, not Target:IsInRange(MeleeRange)) then return "rake filler 2"; end
  end
  -- rake,if=variable.filler=2
  if S.Rake:IsReady() and (VarFiller == "Rake Snapshot") then
    if Cast(S.Rake, nil, nil, not Target:IsInRange(MeleeRange)) then return "rake filler 4"; end
  end
  -- lunar_inspiration,if=variable.filler=3
  if S.LunarInspiration:IsAvailable() and S.Moonfire:IsReady() and (VarFiller == "Moonfire") then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire filler 6"; end
  end
  -- swipe,if=variable.filler=4
  if S.Swipe:IsReady() and (VarFiller == "Swipe") then
    if Cast(S.Swipe, nil, nil, not Target:IsInRange(EightRange)) then return "swipe filler 8"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not Target:IsInRange(MeleeRange)) then return "shred filler 10"; end
  end
end

local function APL()
  -- Update Enemies
  if AoEON() then
    EnemiesMelee = Player:GetEnemiesInMeleeRange(MeleeRange)
    Enemies8y = Player:GetEnemiesInMeleeRange(EightRange)
    EnemiesCountMelee = #EnemiesMelee
    EnemiesCount8y = #Enemies8y
  else
    EnemiesMelee = {}
    Enemies8y = {}
    EnemiesCountMelee = 1
    EnemiesCount8y = 1
  end

  -- Combo Points
  ComboPoints = Player:ComboPoints()
  ComboPointsDeficit = Player:ComboPointsDeficit()

  -- Determine fight_remains
  FightRemains = max(HL.FightRemains(Enemies8ySplash, false), HL.BossFightRemains())

  -- cat_form OOC, if setting is true
  if S.CatForm:IsCastable() and Settings.Feral.ShowCatFormOOC then
    if Cast(S.CatForm) then return "cat_form ooc"; end
  end

  -- Precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end

  if Everyone.TargetIsValid() then
    -- call_action_list,name=owlweave,if=druid.owlweave_cat
    if (Settings.Feral.UseOwlweave and S.BalanceAffinity:IsAvailable()) then
      local ShouldReturn = Owlweave(); if ShouldReturn then return ShouldReturn; end
    end
    -- prowl
    if S.Prowl:IsCastable() then
      if Cast(S.Prowl) then return "prowl main 2"; end
    end
    -- tigers_fury,if=buff.cat_form.down
    if S.TigersFury:IsCastable() and (Player:BuffDown(S.CatForm)) then
      if Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury main 4"; end
    end
    -- cat_form,if=buff.cat_form.down
    if S.CatForm:IsCastable() then
      if Cast(S.CatForm) then return "cat_form main 6"; end
    end
    -- auto_attack,if=!buff.prowl.up&!buff.shadowmeld.up
    -- variable,name=shortest_ttd,value=target.time_to_die
    -- cycling_variable,name=shortest_ttd,op=min,value=target.time_to_die
    VarShortestTTD = 9999
    if EnemiesCount8y > 1 then
      for _, TargetUnit in pairs(Enemies8y) do
        local TUTTD = TargetUnit:TimeToDie()
        if TUTTD < VarShortestTTD then
          VarShortestTTD = TUTTD
        end
      end
    else
      VarShortestTTD = Target:TimeToDie()
    end
    -- run_action_list,name=stealth,if=buff.shadowmeld.up|buff.prowl.up
    if (Player:StealthUp(true, true)) then
      local ShouldReturn = Stealth(); if ShouldReturn then return ShouldReturn; end
    end
    -- skull_bash
    local ShouldReturn = Everyone.Interrupt(InterruptRange, S.SkullBash, Settings.Feral.OffGCDasOffGCD.SkullBash, InterruptStuns); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldown
    if (CDsON()) then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    -- rip,target_if=covenant.necrolord&spell_targets.thrash_cat=1&combo_points>2&refreshable&druid.rip.ticks_gained_on_refresh>variable.rip_ticks&(!buff.bs_inc.up|cooldown.bs_inc.up|(buff.bs_inc.up&cooldown.feral_frenzy.up))
    if S.Rip:IsReady() and (Player:Covenant() == "Necrolord" and EnemiesCountMelee == 1 and ComboPoints > 2 and Target:DebuffRefreshable(S.Rip) and TicksGainedOnRefresh(S.RipDebuff) > VarRipTicks and (Player:BuffDown(BsInc) or BsInc:CooldownUp() or (Player:BuffUp(BsInc) and S.FeralFrenzy:CooldownUp()))) then
      if Cast(S.Rip, nil, nil, not Target:IsInRange(MeleeRange)) then return "rip main 8"; end
    end
    -- run_action_list,name=finisher,if=combo_points>=(5-variable.4cp_bite)
    if (ComboPoints >= (5 - VarFourCPBite)) then
      local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
    end
    -- primal_wrath,if=druid.primal_wrath.ticks_gained_on_refresh>=20&combo_points>=2,line_cd=5
    if S.PrimalWrath:IsReady() and (EnemiesCount8y > 1 and ComboPoints >= 2 and S.PrimalWrath:TimeSinceLastCast() > 5 and PrimalWrathTicksGainedOnRefresh() >= 20) then
      if Cast(S.PrimalWrath, nil, nil, not Target:IsInRange(EightRange)) then return "primal_wrath main 10"; end
    end
    -- call_action_list,name=stealth,if=buff.bs_inc.up|buff.sudden_ambush.up
    if (Player:BuffUp(BsInc) or Player:BuffUp(S.SuddenAmbushBuff)) then
      local ShouldReturn = Stealth(); if ShouldReturn then return ShouldReturn; end
    end
    -- pool_resource,if=talent.bloodtalons.enabled&buff.bloodtalons.down&(energy+3.5*energy.regen+(40*buff.clearcasting.up))<(115-23*buff.incarnation_king_of_the_jungle.up)&active_bt_triggers=0
    if (S.Bloodtalons:IsAvailable() and Player:BuffDown(S.BloodtalonsBuff) and (Player:Energy() + 3.5 * Player:EnergyRegen() + (40 * num(Player:BuffUp(S.Clearcasting)))) < (115 - 23 * num(Player:BuffUp(S.Incarnation))) and CountActiveBtTriggers() == 0) then
      if Cast(S.Pool) then return "Pool Energy for Bloodtalons"; end
    end
    -- run_action_list,name=bloodtalons,if=talent.bloodtalons.enabled&buff.bloodtalons.down
    if (S.Bloodtalons:IsAvailable() and Player:BuffDown(S.BloodtalonsBuff)) then
      local ShouldReturn = Bloodtalons(); if ShouldReturn then return ShouldReturn; end
    end
    -- ferocious_bite,target_if=max:target.time_to_die,if=buff.apex_predators_craving.up
    if S.FerociousBite:IsReady() then
      if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfFerociousBiteMain12, not Target:IsInRange(MeleeRange)) then return "ferocious_bite main 12"; end
    end
    -- pool_resource,for_next=1
    -- rake,target_if=(refreshable|persistent_multiplier>dot.rake.pmultiplier)&druid.rake.ticks_gained_on_refresh>spell_targets.swipe_cat*2-2
    if S.Rake:IsCastable() and ((Target:DebuffRefreshable(S.RakeDebuff) or Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake)) and TicksGainedOnRefresh(S.RakeDebuff) > EnemiesCount8y * 2 - 2) then
      if Player:Energy() >= 35 then
        if Cast(S.Rake, nil, nil, not Target:IsInRange(MeleeRange)) then return "rake target main 14"; end
      else
        if CastPooling(S.Rake, Player:EnergyTimeToX(35)) then return "Pool for rake target main 14"; end
      end
    end
    if S.Rake:IsCastable() and AoEON() then
      for _, CycleUnit in pairs(Enemies8y) do
        if CycleUnit:GUID() ~= Target:GUID() and not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and EvaluateCycleRakeMain14(CycleUnit) then
          if Player:Energy() >= 35 then
            if HR.CastLeftNameplate(CycleUnit, S.Rake) then return "rake off-target main 14"; end
          else
            if CastPooling(S.Pool, Player:EnergyTimeToX(35)) then return "Pool for rake off-target main 14"; end
          end
        end
      end
    end
    -- lunar_inspiration,target_if=refreshable&druid.lunar_inspiration.ticks_gained_on_refresh>spell_targets.swipe_cat*2-2
    if S.LunarInspiration:IsAvailable() and S.Moonfire:IsReady() then
      if Everyone.CastCycle(S.Moonfire, Enemies8y, EvaluateCycleMoonfireMain16, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire main 16"; end
    end
    -- pool_resource,for_next=1
    -- thrash_cat,target_if=refreshable&druid.thrash_cat.ticks_gained_on_refresh>(4+spell_targets.thrash_cat*4)%(1+mastery_value)-conduit.taste_for_blood.enabled-covenant.necrolord
    if S.Thrash:IsCastable() and (Target:DebuffRefreshable(S.ThrashDebuff) and TicksGainedOnRefresh(S.ThrashDebuff) > (4 + EnemiesCount8y * 4) / (1 + (Player:MasteryPct() / 100)) - num(S.TasteForBlood:ConduitEnabled()) - num(Player:Covenant() == "Necrolord")) then
      if Player:Energy() >= 40 then
        if Cast(S.Thrash, nil, nil, not Target:IsInRange(EightRange)) then return "thrash target main 18"; end
      else
        if CastPooling(S.Thrash, Player:EnergyTimeToX(40)) then return "Pool for thrash target main 18"; end
      end
    end
    if S.Thrash:IsCastable() and AoEON() then
      for _, CycleUnit in pairs(Enemies8y) do
        if CycleUnit:GUID() ~= Target:GUID() and not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and EvaluateCycleThrashMain18(CycleUnit) then
          if Player:Energy() >= 40 then
            if HR.CastLeftNameplate(CycleUnit, S.Thrash) then return "thrash off-target main 18"; end
          else
            if CastPooling(S.Pool, Player:EnergyTimeToX(40)) then return "Pool for thrash off-target main 18"; end
          end
        end
      end
    end
    -- pool_resource,for_next=1
    -- brutal_slash,if=(raid_event.adds.in>(1+max_charges-charges_fractional)*recharge_time)&(spell_targets.brutal_slash*action.brutal_slash.damage%action.brutal_slash.cost)>(action.shred.damage%action.shred.cost)
    if S.BrutalSlash:IsCastable() and ((EnemiesCount8y * S.BrutalSlash:Damage() / S.BrutalSlash:Cost()) > (S.Shred:Damage() / S.Shred:Cost())) then
      if CastPooling(S.BrutalSlash, Player:EnergyTimeToX(25), not Target:IsInRange(EightRange)) then return "brutal_slash main 20"; end
    end
    -- swipe_cat,if=spell_targets.swipe_cat>1+buff.bs_inc.up*2
    if S.Swipe:IsReady() and (EnemiesCount8y > 1 + num(Player:BuffUp(BsInc)) * 2) then
      if Cast(S.Swipe, nil, nil, not Target:IsInRange(EightRange)) then return "swipe main 22"; end
    end
    -- thrash_cat,if=spell_targets.thrash_cat>3
    if S.Thrash:IsReady() and (EnemiesCount8y > 3) then
      if Cast(S.Thrash, nil, nil, not Target:IsInRange(EightRange)) then return "thrash main 24"; end
    end
    -- shred,if=buff.clearcasting.up
    if S.Shred:IsReady() and (Player:BuffUp(S.Clearcasting)) then
      if Cast(S.Shred, nil, nil, not Target:IsInRange(MeleeRange)) then return "shred main 26"; end
    end
    -- rake,target_if=buff.bs_inc.up&druid.rake.ticks_gained_on_refresh>2
    if S.Rake:IsReady() and (Player:BuffUp(BsInc) and TicksGainedOnRefresh(S.RakeDebuff) > 2) then
      if Cast(S.Rake, nil, nil, not Target:IsInRange(EightRange)) then return "rake main 28"; end
    end
    -- call_action_list,name=filler
    if (true) then
      local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool if nothing else to do
    if (true) then
      if Cast(S.Pool) then return "Pool Energy"; end
    end
  end
end

local function OnInit()
end

HR.SetAPL(103, APL, OnInit)
