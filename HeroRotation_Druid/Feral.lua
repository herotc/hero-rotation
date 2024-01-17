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
-- lua
local mathfloor   = math.floor

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
  I.AshesoftheEmbersoul:ID(),
  I.BandolierofTwistedBlades:ID(),
  I.ManicGrieftorch:ID(),
  I.MirrorofFracturedTomorrows:ID(),
  I.MydasTalisman:ID(),
  I.WitherbarksBranch:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Rotation Variables
local VarNeedBT, VarAlign3Mins, VarLastConvoke, VarLastZerk, VarZerkBiteweave, VarRegrowth, VarEasySwipe
local VarForceAlign2Min, VarAlignCDs
local ComboPoints, ComboPointsDeficit
local MeleeRange, AoERange
local IsInMeleeRange, IsInAoERange
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
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED")

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
    if not Lowest or EnemyPMult < Lowest then
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
  if not OldTicks then OldTicks = 0 end
  local TicksAdded = NewTicks - OldTicks
  return TicksAdded
end

local function HighestTTD(enemies)
  if not enemies then return 0 end
  local HighTTD = 0
  local HighTTDTar = nil
  for _, enemy in pairs(enemies) do
    local TTD = enemy:TimeToDie()
    if TTD > HighTTD then
      HighTTD = TTD
      HighTTDTar = enemy
    end
  end
  return HighTTD, HighTTDTar
end

-- CastCycle/CastTargetIf Functions
-- CastTargetIf Filters
local function EvaluateTargetIfFilterAdaptiveSwarm(TargetUnit)
  -- target_if=max:(1+dot.adaptive_swarm_damage.stack)*dot.adaptive_swarm_damage.stack<3*time_to_die
  return ((1 + TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff)) * num(TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3) * TargetUnit:TimeToDie())
end

local function EvaluateTargetIfFilterLIMoonfire(TargetUnit)
  -- target_if=max:(3*refreshable)+dot.adaptive_swarm_damage.ticking
  return ((3 * num(TargetUnit:DebuffRefreshable(S.LIMoonfireDebuff))) + num(TargetUnit:DebuffUp(S.LIMoonfireDebuff)))
end

local function EvaluateTargetIfFilterRake(TargetUnit)
  -- target_if=min:(25*(persistent_multiplier<dot.rake.pmultiplier)+dot.rake.remains)
  return (25 * num(Player:PMultiplier(S.Rake) < TargetUnit:PMultiplier(S.Rake)) + TargetUnit:DebuffRemains(S.RakeDebuff))
end

local function EvaluateTargetIfFilterRakeTicks(TargetUnit)
  -- target_if=max:druid.rake.ticks_gained_on_refresh
  return (TicksGainedOnRefresh(S.RakeDebuff, TargetUnit))
end

local function EvaluateTargetIfFilterTTD(TargetUnit)
  -- target_if=min:target.time_to_die
  return (TargetUnit:TimeToDie())
end

-- CastTargetIf Conditions
local function EvaluateTargetIfAdaptiveSwarm(TargetUnit)
  -- if=dot.adaptive_swarm_damage.stack<3&talent.unbridled_swarm.enabled&spell_targets.swipe_cat>1
  -- Note: Everything but stack count handled before CastTargetIf call
  return (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3)
end

local function EvaluateTargetIfBrutalSlashAoeBuilder(TargetUnit)
  -- if=cooldown.brutal_slash.full_recharge_time<4|target.time_to_die<5
  return (S.BrutalSlash:FullRechargeTime() < 4 or TargetUnit:TimeToDie() < 5)
end

local function EvaluateTargetIfBrutalSlashBT(TargetUnit)
  -- if=(cooldown.brutal_slash.full_recharge_time<4|target.time_to_die<5)&(buff.bt_brutal_slash.down&(buff.bs_inc.up|variable.need_bt))
  return ((S.BrutalSlash:FullRechargeTime() < 4 or TargetUnit:TimeToDie() < 5) and (BTBuffDown(S.BrutalSlash) and (Player:BuffUp(BsInc) or VarNeedBT)))
end

local function EvaluateTargetIfConvokeCD(TargetUnit)
  -- if=fight_remains<5|(buff.smoldering_frenzy.up|!set_bonus.tier31_4pc)&(dot.rip.remains>4-talent.ashamanes_guidance&buff.tigers_fury.up&combo_points<2)&(debuff.dire_fixation.up|!talent.dire_fixation.enabled|spell_targets.swipe_cat>1)&((target.time_to_die<fight_remains&target.time_to_die>5-talent.ashamanes_guidance.enabled)|target.time_to_die=fight_remains)
  return (FightRemains < 5 or (Player:BuffUp(S.SmolderingFrenzyBuff) or not Player:HasTier(31, 4)) and (TargetUnit:DebuffRemains(S.RipDebuff) > 4 - num(S.AshamanesGuidance:IsAvailable()) and Player:BuffUp(S.TigersFury) and ComboPoints < 2) and (TargetUnit:DebuffUp(S.DireFixationDebuff) or not S.DireFixation:IsAvailable() or EnemiesCount11y > 1) and ((TargetUnit:TimeToDie() < FightRemains and TargetUnit:TimeToDie() > 5 - num(S.AshamanesGuidance:IsAvailable())) or TargetUnit:TimeToDie() == FightRemains))
end

local function EvaluateTargetIfLIMoonfireAoEBuilder(TargetUnit)
  -- if=spell_targets.swipe_cat<5&dot.moonfire.refreshable
  -- Note: Target count checked before CastTargetIf call.
  return (TargetUnit:DebuffRefreshable(S.LIMoonfireDebuff))
end

local function EvaluateTargetIfLIMoonfireBT(TargetUnit)
  -- target_if=max:ticks_gained_on_refresh
  return (TicksGainedOnRefresh(S.LIMoonfireDebuff, TargetUnit))
end

local function EvaluateTargetIfRakeAoeBuilder(TargetUnit)
  -- if=buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier
  return (Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake))
end

local function EvaluateTargetIfRakeBloodtalons(TargetUnit)
  -- if=(refreshable|buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier)&buff.bt_rake.down
  return ((TargetUnit:DebuffRefreshable(S.RakeDebuff) or Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake)) and BTBuffDown(S.Rake))
end

local function EvaluateTargetIfFeralFrenzy(TargetUnit)
  -- if=((combo_points<3|time<10&combo_points<4)&(!talent.dire_fixation.enabled|debuff.dire_fixation.up|spell_targets.swipe_cat>1)&(target.time_to_die<fight_remains&target.time_to_die>6|target.time_to_die=fight_remains))&!(spell_targets=1&talent.convoke_the_spirits.enabled)
  return (((ComboPoints < 3 or HL.CombatTime() < 10 and ComboPoints < 4) and (not S.DireFixation:IsAvailable() or TargetUnit:DebuffUp(S.DireFixationDebuff) or EnemiesCount11y > 1) and (TargetUnit:TimeToDie() < FightRemains and Target:TimeToDie() > 6 or TargetUnit:TimeToDie() == FightRemains)) and not (EnemiesCount11y == 1 and S.ConvoketheSpirits:IsAvailable()))
end

local function EvaluateTargetIfFerociousBiteBerserk(TargetUnit)
  -- if=combo_points=5&dot.rip.remains>8&variable.zerk_biteweave&spell_targets.swipe_cat>1
  return TargetUnit:DebuffRemains(S.RipDebuff) > 5
end

-- CastCycle Conditions
local function EvaluateCycleAdaptiveSwarm(TargetUnit)
  -- target_if=(!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&dot.adaptive_swarm_damage.stack<3&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight&target.time_to_die>5
  return ((TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) or TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 2) and TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and not S.AdaptiveSwarm:InFlight() and TargetUnit:TimeToDie() > 5)
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
  -- target_if=buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier&buff.bt_rake.down
  -- bt_rake check handled before CastCycle
  return (Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake))
end

local function EvaluateCycleRakeMain(TargetUnit)
  -- target_if=persistent_multiplier>dot.rake.pmultiplier
  return (Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake))
end

local function EvaluateCycleRip(TargetUnit)
  -- target_if=((set_bonus.tier31_2pc&cooldown.feral_frenzy.remains<2&dot.rip.remains<10)|(time<8|buff.bloodtalons.up|!talent.bloodtalons.enabled|(buff.bs_inc.up&dot.rip.remains<2))&refreshable)&(!talent.primal_wrath.enabled|spell_targets.swipe_cat=1)&!(buff.smoldering_frenzy.up&dot.rip.remains>2)
  return (((Player:HasTier(31, 2) and S.FeralFrenzy:CooldownRemains() < 2 and TargetUnit:DebuffRemains(S.RipDebuff) < 10) or (HL.CombatTime() < 8 or Player:BuffUp(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable() or (Player:BuffUp(BsInc) and TargetUnit:DebuffRemains(S.RipDebuff) < 2)) and TargetUnit:DebuffRefreshable(S.RipDebuff)) and (not S.PrimalWrath:IsAvailable() or EnemiesCount11y == 1) and not (Player:BuffUp(S.SmolderingFrenzyBuff) and TargetUnit:DebuffRemains(S.RipDebuff) > 2))
end

local function EvaluateCycleThrash(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.ThrashDebuff))
end

-- APL Functions
local function Precombat()
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and Everyone.GroupBuffMissing(S.MarkoftheWildBuff) then
    if Cast(S.MarkoftheWild, Settings.Commons.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat"; end
  end
  -- cat_form,if=!buff.cat_form.up
  if S.CatForm:IsCastable() then
    if Cast(S.CatForm) then return "cat_form precombat 2"; end
  end
  -- heart_of_the_wild
  if S.HeartoftheWild:IsCastable() then
    if Cast(S.HeartoftheWild, Settings.Feral.GCDasOffGCD.HeartOfTheWild) then return "heart_of_the_wild precombat 4"; end
  end
  -- use_item,name=algethar_puzzle_box
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() then
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
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake precombat 8"; end
  end
end

local function Variables()
  -- variable,name=need_bt,value=talent.bloodtalons.enabled&buff.bloodtalons.stack<=1
  VarNeedBT = (S.Bloodtalons:IsAvailable() and Player:BuffStack(S.BloodtalonsBuff) <= 1)
  -- variable,name=align_3minutes,value=spell_targets.swipe_cat=1&!fight_style.dungeonslice
  local DungeonSlice = Player:IsInParty() and not Player:IsInRaid()
  VarAlign3Mins = EnemiesCount11y == 1 and not DungeonSlice
  -- variable,name=lastConvoke,value=fight_remains>cooldown.convoke_the_spirits.remains+3&((talent.ashamanes_guidance.enabled&fight_remains<(cooldown.convoke_the_spirits.remains+60))|(!talent.ashamanes_guidance.enabled&fight_remains<(cooldown.convoke_the_spirits.remains+120)))
  VarLastConvoke = FightRemains > S.ConvoketheSpirits:CooldownRemains() + 3 and ((S.AshamanesGuidance:IsAvailable() and FightRemains < S.ConvoketheSpirits:CooldownRemains() + 60) or (not S.AshamanesGuidance:IsAvailable() and FightRemains < S.ConvoketheSpirits:CooldownRemains() + 12))
  -- variable,name=lastZerk,value=fight_remains>(30+(cooldown.bs_inc.remains%1.6))&((talent.berserk_heart_of_the_lion.enabled&fight_remains<(90+(cooldown.bs_inc.remains%1.6)))|(!talent.berserk_heart_of_the_lion.enabled&fight_remains<(180+cooldown.bs_inc.remains)))
  VarLastZerk = FightRemains > (30 + (BsInc:CooldownRemains() / 1.6)) and ((S.BerserkHeartoftheLion:IsAvailable() and FightRemains < (90 + (BsInc:CooldownRemains() / 1.6))) or (not S.BerserkHeartoftheLion:IsAvailable() and FightRemains < (180 + BsInc:CooldownRemains())))
  -- variable,name=zerk_biteweave,op=reset
  VarZerkBiteweave = Settings.Feral.UseZerkBiteweave
  -- variable,name=regrowth,op=reset
  VarRegrowth = Settings.Feral.ShowHealSpells
  -- variable,name=easy_swipe,op=reset
  VarEasySwipe = Settings.Feral.UseEasySwipe
  -- variable,name=force_align_2min,op=reset
  VarForceAlign2Min = Settings.Feral.Align2Min
  -- variable,name=align_cds,value=(variable.force_align_2min|equipped.witherbarks_branch|equipped.ashes_of_the_embersoul|(time+fight_remains>150&time+fight_remains<200|time+fight_remains>270&time+fight_remains<295|time+fight_remains>395&time+fight_remains<400|time+fight_remains>490&time+fight_remains<495))&talent.convoke_the_spirits.enabled&fight_style.patchwerk&spell_targets.swipe_cat=1&set_bonus.tier31_2pc
  local CombatTime = HL.CombatTime()
  local TimeCheck = CombatTime + FightRemains
  VarAlignCDs = (VarForceAlign2Min or I.WitherbarksBranch:IsEquipped() or I.AshesoftheEmbersoul:IsEquipped() or (TimeCheck > 150 and TimeCheck < 200 or TimeCheck > 270 and TimeCheck < 295 or TimeCheck > 395 and TimeCheck < 400 or TimeCheck > 490 and TimeCheck < 495)) and S.ConvoketheSpirits:IsAvailable() and not DungeonSlice and EnemiesCount11y == 1 and Player:HasTier(31, 2)
end

local function Builder()
  -- thrash_cat,target_if=refreshable&(!talent.dire_fixation.enabled|talent.dire_fixation.enabled&debuff.dire_fixation.up)&buff.clearcasting.react&!talent.thrashing_claws.enabled
  if S.Thrash:IsCastable() and (Target:DebuffRefreshable(S.ThrashDebuff) and (not S.DireFixation:IsAvailable() or S.DireFixation:IsAvailable() and Target:DebuffUp(S.DireFixationDebuff)) and Player:BuffUp(S.Clearcasting) and not S.ThrashingClaws:IsAvailable()) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash builder 2"; end
  end
  -- shred,if=(buff.clearcasting.react|(talent.dire_fixation.enabled&!debuff.dire_fixation.up))&!(variable.need_bt&buff.bt_shred.up)
  if S.Shred:IsReady() and ((Player:BuffUp(S.Clearcasting) or (S.DireFixation:IsAvailable() and Target:DebuffDown(S.DireFixationDebuff))) and not (VarNeedBT and BTBuffUp(S.Shred))) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred builder 4"; end
  end
  -- brutal_slash,if=cooldown.brutal_slash.full_recharge_time<4&!(variable.need_bt&buff.bt_brutal_slash.up)
  if S.BrutalSlash:IsReady() and (S.BrutalSlash:FullRechargeTime() < 4 and not (VarNeedBT and BTBuffUp(S.BrutalSlash))) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash builder 6"; end
  end
  -- pool_resource,if=!action.rake.ready&(dot.rake.refreshable|(buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier&dot.rake.remains>6))&!buff.clearcasting.react&!(variable.need_bt&buff.bt_rake.up)
  if not S.Rake:IsReady() and (Target:DebuffRefreshable(S.RakeDebuff) or (Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake) and Target:DebuffRemains(S.RakeDebuff) > 6)) and Player:BuffDown(S.Clearcasting) and not (VarNeedBT and BTBuffUp(S.Rake)) then
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Rake in Builder()"; end
  end
  -- shadowmeld,if=action.rake.ready&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!(variable.need_bt&buff.bt_rake.up)&!buff.prowl.up
  if S.Shadowmeld:IsCastable() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and not (VarNeedBT and BTBuffUp(S.Rake)) and Player:BuffDown(S.Prowl)) then
    if Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "shadowmeld builder 8"; end
  end
  -- rake,if=(refreshable|buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier)&!(variable.need_bt&buff.bt_rake.up)
  if S.Rake:IsReady() and ((Target:DebuffRefreshable(S.RakeDebuff) or Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake)) and not (VarNeedBT and BTBuffUp(S.Rake))) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake builder 10"; end
  end
  -- moonfire_cat,target_if=refreshable
  if S.LIMoonfire:IsReady() then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfire, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat builder 8"; end
  end
  -- thrash_cat,target_if=refreshable&!talent.thrashing_claws.enabled
  if S.Thrash:IsCastable() and (Target:DebuffRefreshable(S.ThrashDebuff) and not S.ThrashingClaws:IsAvailable()) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash builder 10"; end
  end
  -- brutal_slash,if=!(variable.need_bt&buff.bt_brutal_slash.up)
  if S.BrutalSlash:IsReady() and (not (VarNeedBT and BTBuffUp(S.BrutalSlash))) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash builder 12"; end
  end
  -- swipe_cat,if=spell_targets.swipe_cat>1|(talent.wild_slashes.enabled&(debuff.dire_fixation.up|!talent.dire_fixation.enabled))
  if S.Swipe:IsReady() and (EnemiesCount11y > 1 or (S.WildSlashes:IsAvailable() and (Target:DebuffUp(S.DireFixationDebuff) or not S.DireFixation:IsAvailable()))) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe builder 14"; end
  end
  -- shred,if=!(variable.need_bt&buff.bt_shred.up)
  if S.Shred:IsReady() and (not (VarNeedBT and BTBuffUp(S.Shred))) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred builder 16"; end
  end
  -- moonfire_cat,if=variable.need_bt&buff.bt_moonfire.down
  if S.LIMoonfire:IsReady() and (VarNeedBT and BTBuffDown(S.LIMoonfire)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat builder 18"; end
  end
  -- swipe_cat,if=variable.need_bt&buff.bt_swipe.down
  if S.Swipe:IsReady() and (VarNeedBT and BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe builder 20"; end
  end
  -- rake,if=variable.need_bt&buff.bt_rake.down&persistent_multiplier>=dot.rake.pmultiplier
  if S.Rake:IsReady() and (VarNeedBT and BTBuffDown(S.Rake) and Player:PMultiplier(S.Rake) >= Target:PMultiplier(S.Rake)) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake builder 22"; end
  end
  -- thrash_cat,if=variable.need_bt&buff.bt_thrash.down
  if S.Thrash:IsCastable() and (VarNeedBT and BTBuffDown(S.Thrash)) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash builder 24"; end
  end
end

local function AoeBuilder()
  -- brutal_slash,target_if=min:target.time_to_die,if=cooldown.brutal_slash.full_recharge_time<4|target.time_to_die<5
  if S.BrutalSlash:IsReady() then
    if Everyone.CastTargetIf(S.BrutalSlash, Enemies11y, "min", EvaluateTargetIfFilterTTD, EvaluateTargetIfBrutalSlashAoeBuilder, not IsInAoERange) then return "brutal_slash aoe_builder 2"; end
  end
  -- thrash_cat,target_if=refreshable,if=buff.clearcasting.react|(spell_targets.thrash_cat>10|(spell_targets.thrash_cat>5&!talent.doubleclawed_rake.enabled))&!talent.thrashing_claws
  if S.Thrash:IsReady() and (Player:BuffUp(S.Clearcasting) or (EnemiesCount11y > 10 or (EnemiesCount11y > 5 and not S.DoubleClawedRake:IsAvailable())) and not S.ThrashingClaws:IsAvailable()) then
    if Everyone.CastCycle(S.Thrash, Enemies11y, EvaluateCycleThrash, not IsInAoERange) then return "thrash aoe_builder 4"; end
  end
  -- shadowmeld,target_if=max:druid.rake.ticks_gained_on_refresh,if=action.rake.ready&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.prowl.up&!buff.apex_predators_craving.up
  if S.Shadowmeld:IsReady() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (DebuffRefreshAny(Enemies11y, S.RakeDebuff) or LowRakePMult(Enemies11y) < 1.4) and Player:BuffDown(S.Prowl) and Player:BuffDown(S.ApexPredatorsCravingBuff)) then
    if Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "shadowmeld aoe_builder 6"; end
  end
  -- shadowmeld,target_if=druid.rake.ticks_gained_on_refresh,if=action.rake.ready&!buff.sudden_ambush.up&dot.rake.pmultiplier<1.4&!buff.prowl.up&!buff.apex_predators_craving.up
  if S.Shadowmeld:IsReady() and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and LowRakePMult(Enemies11y) < 1.4 and Player:BuffDown(S.Prowl) and Player:BuffDown(S.ApexPredatorsCravingBuff)) then
    if Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "shadowmeld aoe_builder 8"; end
  end
  -- rake,target_if=max:druid.rake.ticks_gained_on_refresh,if=buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier
  if S.Rake:IsReady() and (Player:BuffUp(S.SuddenAmbushBuff)) then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeTicks, EvaluateTargetIfRakeAoeBuilder, not IsInMeleeRange) then return "rake aoe_builder 10"; end
  end
  -- rake,target_if=buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier|refreshable
  if S.Rake:IsReady() then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRakeAoeBuilder, not IsInMeleeRange) then return "rake aoe_builder 12"; end
  end
  -- thrash_cat,target_if=refreshable
  if S.Thrash:IsReady() and (Target:DebuffRefreshable(S.ThrashDebuff)) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash aoe_builder 14"; end
  end
  -- brutal_slash
  if S.BrutalSlash:IsReady() then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash aoe_builder 16"; end
  end
  -- moonfire_cat,target_if=max:(3*refreshable)+dot.adaptive_swarm_damage.ticking,if=spell_targets.swipe_cat<5&dot.moonfire.refreshable
  if S.LIMoonfire:IsReady() and (EnemiesCount11y < 5) then
    if Everyone.CastTargetIf(S.LIMoonfire, Enemies11y, "max", EvaluateTargetIfFilterLIMoonfire, EvaluateTargetIfLIMoonfireAoEBuilder, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat aoe_builders 18"; end
  end
  -- swipe_cat
  if S.Swipe:IsReady() then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe aoe_builder 20"; end
  end
  -- moonfire_cat,target_if=max:(3*refreshable)+dot.adaptive_swarm_damage.ticking,if=dot.moonfire.refreshable
  if S.LIMoonfire:IsReady() then
    if Everyone.CastTargetIf(S.LIMoonfire, Enemies11y, "max", EvaluateTargetIfFilterLIMoonfire, EvaluateTargetIfLIMoonfireAoEBuilder, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat aoe_builders 22"; end
  end
  -- shred,target_if=max:target.time_to_die,if=(spell_targets.swipe_cat<4|talent.dire_fixation.enabled)&!buff.sudden_ambush.up&!(variable.lazy_swipe&talent.wild_slashes)
  if S.Shred:IsReady() and ((EnemiesCount11y < 4 or S.DireFixation:IsAvailable()) and Player:BuffDown(S.SuddenAmbushBuff) and not (VarEasySwipe and S.WildSlashes:IsAvailable())) then
    if Everyone.CastTargetIf(S.Shred, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, nil, not IsInMeleeRange) then return "shred aoe_builder 24"; end
  end
  -- thrash_cat
  if S.Thrash:IsReady() then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash aoe_builder 26"; end
  end
end

local function Finisher()
  -- pool_resource,for_next=1,if=buff.bs_inc.up
  -- primal_wrath,if=(dot.primal_wrath.refreshable|(talent.tear_open_wounds.enabled|(spell_targets.swipe_cat>4&!talent.rampant_ferocity.enabled)))&spell_targets.primal_wrath>1&talent.primal_wrath.enabled
  if S.PrimalWrath:IsCastable() and ((Target:DebuffRefreshable(S.PrimalWrath) or (S.TearOpenWounds:IsAvailable() or (EnemiesCount11y > 4 and not S.RampantFerocity:IsAvailable()))) and EnemiesCount11y > 1 and S.PrimalWrath:IsAvailable()) then
    if CastPooling(S.PrimalWrath, Player:EnergyTimeToX(20)) then return "primal_wrath finisher 2"; end
  end
  -- rip,target_if=((set_bonus.tier31_2pc&cooldown.feral_frenzy.remains<2&dot.rip.remains<10)|(time<8|buff.bloodtalons.up|!talent.bloodtalons.enabled|(buff.bs_inc.up&dot.rip.remains<2))&refreshable)&(!talent.primal_wrath.enabled|spell_targets.swipe_cat=1)&!(buff.smoldering_frenzy.up&dot.rip.remains>2)
  if S.Rip:IsReady() then
    if Everyone.CastCycle(S.Rip, EnemiesMelee, EvaluateCycleRip, not IsInMeleeRange) then return "rip finisher 4"; end
  end
  -- pool_resource,for_next=1,if=!action.tigers_fury.ready&buff.apex_predators_craving.down
  -- ferocious_bite,max_energy=1,target_if=max:target.time_to_die,if=buff.apex_predators_craving.down&(!buff.bs_inc.up|buff.bs_inc.up&!talent.soul_of_the_forest.enabled)
  if S.FerociousBite:IsReady() and (Player:BuffDown(S.ApexPredatorsCravingBuff) and (Player:BuffDown(BsInc) or Player:BuffUp(BsInc) and not S.SouloftheForest:IsAvailable())) then
    if not S.TigersFury:IsReady() and Player:BuffDown(S.ApexPredatorsCravingBuff) then
      if CastPooling(S.FerociousBite, Player:EnergyTimeToX(50)) then return "ferocious_bite finisher 6"; end
    elseif Player:Energy() >= 50 then
      if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, nil, not IsInMeleeRange) then return "ferocious_bite finisher 8"; end
    end
  end
  -- ferocious_bite,target_if=max:target.time_to_die,if=(buff.bs_inc.up&talent.soul_of_the_forest.enabled)|buff.apex_predators_craving.up
  if S.FerociousBite:IsReady() and ((Player:BuffUp(BsInc) and S.SouloftheForest:IsAvailable()) or Player:BuffUp(S.ApexPredatorsCravingBuff)) then
    if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, nil, not IsInMeleeRange) then return "ferocious_bite finisher 10"; end
  end
end

local function Berserk()
  -- ferocious_bite,target_if=max:target.time_to_die,if=combo_points=5&dot.rip.remains>8&variable.zerk_biteweave&spell_targets.swipe_cat>1
  if S.FerociousBite:IsReady() and (ComboPoints == 5 and VarZerkBiteweave and EnemiesCount11y > 1) then
    if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfFerociousBiteBerserk, not IsInMeleeRange) then return "ferocious_bite berserk 2"; end
  end
  -- call_action_list,name=finisher,if=combo_points=5&!(buff.overflowing_power.stack<=1&active_bt_triggers=2&buff.bloodtalons.stack<=1&set_bonus.tier30_4pc)
  if ComboPoints == 5 and not (Player:BuffStack(S.OverflowingPowerBuff) <= 1 and CountActiveBtTriggers() == 2 and Player:BuffStack(S.BloodtalonsBuff) <= 1 and Player:HasTier(30, 4)) then
    local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
  end
  -- run_action_list,name=aoe_builder,if=spell_targets.swipe_cat>1
  if EnemiesCount11y > 1 then
    local ShouldReturn = AoeBuilder(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for AoeBuilder()"; end
  end
  -- prowl,if=!(buff.bt_rake.up&active_bt_triggers=2)&(action.rake.ready&gcd.remains=0&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.shadowmeld.up)
  if S.Prowl:IsReady() and (not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2) and (S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and Player:BuffDown(S.Shadowmeld))) then
    if Cast(S.Prowl) then return "prowl berserk 4"; end
  end
  -- shadowmeld,if=!(buff.bt_rake.up&active_bt_triggers=2)&action.rake.ready&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.prowl.up
  if S.Shadowmeld:IsCastable() and (not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2) and S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and Player:BuffDown(S.Prowl)) then
    if Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "shadowmeld berserk 6"; end
  end
  -- rake,if=!(buff.bt_rake.up&active_bt_triggers=2)&(dot.rake.remains<3|buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier)
  if S.Rake:IsReady() and (not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2) and (Target:DebuffRemains(S.RakeDebuff) < 3 or (Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake)))) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake berserk 8"; end
  end
  -- shred,if=active_bt_triggers=2&buff.bt_shred.down
  if S.Shred:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.Shred)) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred berserk 10"; end
  end
  -- brutal_slash,if=active_bt_triggers=2&buff.bt_brutal_slash.down
  if S.BrutalSlash:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.BrutalSlash)) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash berserk 12"; end
  end
  -- moonfire_cat,if=active_bt_triggers=2&buff.bt_moonfire.down
  if S.LIMoonfire:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.LIMoonfire)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat berserk 14"; end
  end
  -- thrash_cat,if=active_bt_triggers=2&buff.bt_thrash.down&!talent.thrashing_claws&variable.need_bt
  if S.Thrash:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.Thrash) and not S.ThrashingClaws:IsAvailable() and VarNeedBT) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash berserk 16"; end
  end
  -- moonfire_cat,target_if=refreshable
  if S.LIMoonfire:IsReady() then
    if Everyone.CastCycle(S.LIMoonfire, Enemies11y, EvaluateCycleLIMoonfire, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat berserk 18"; end
  end
  -- brutal_slash,if=cooldown.brutal_slash.charges>1&(!talent.dire_fixation.enabled|debuff.dire_fixation.up)
  if S.BrutalSlash:IsReady() and (S.BrutalSlash:Charges() > 1 and (not S.DireFixation:IsAvailable() or Target:DebuffUp(S.DireFixationDebuff))) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash berserk 20"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred berserk 22"; end
  end
end

local function Cooldown()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=algethar_puzzle_box,if=fight_remains<35|(!variable.align_3minutes)
    if I.AlgetharPuzzleBox:IsEquippedAndReady() and (FightRemains < 35 or not VarAlign3Mins) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box cooldown 2"; end
    end
    -- use_item,name=algethar_puzzle_box,if=variable.align_3minutes&(cooldown.bs_inc.remains<3&(!variable.lastZerk|!variable.lastConvoke|(variable.lastConvoke&cooldown.convoke_the_spirits.remains<13)))
    if I.AlgetharPuzzleBox:IsEquippedAndReady() and (VarAlign3Mins and (BsInc:CooldownRemains() < 3 and (not VarLastZerk or not VarLastConvoke or (VarLastConvoke and S.ConvoketheSpirits:CooldownRemains() < 13)))) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box cooldown 4"; end
    end
  end
  -- incarnation,target_if=max:target.time_to_die,if=(target.time_to_die<fight_remains&target.time_to_die>25)|target.time_to_die=fight_remains
  local HighTTD, _ = HighestTTD(Enemies11y)
  if S.Incarnation:IsReady() and ((HighTTD < FightRemains and HighTTD > 25) or HighTTD == FightRemains) then
    if Cast(S.Incarnation, Settings.Feral.GCDasOffGCD.BsInc) then return "incarnation cooldown 6"; end
  end
  -- berserk,if=fight_remains<25|talent.convoke_the_spirits.enabled&(fight_remains<cooldown.convoke_the_spirits.remains|(variable.align_cds&(action.feral_frenzy.ready&(combo_points<3|(time<10&combo_points<4))|time<10&combo_points<4)&cooldown.convoke_the_spirits.remains<10))
  if S.Berserk:IsReady() and (FightRemains < 25 or S.ConvoketheSpirits:IsAvailable() and (FightRemains < S.ConvoketheSpirits:CooldownRemains() or (VarAlignCDs and (S.FeralFrenzy:IsReady() and (ComboPoints < 3 or (HL.CombatTime() < 10 and ComboPoints < 4)) or HL.CombatTime() < 10 and ComboPoints < 4) and S.ConvoketheSpirits:CooldownRemains() < 10))) then
    if Cast(S.Berserk, Settings.Feral.GCDasOffGCD.BsInc) then return "berserk cooldown 8"; end
  end
  -- berserk,target_if=max:target.time_to_die,if=!variable.align_cds&!(!talent.frantic_momentum.enabled&equipped.witherbarks_branch&spell_targets.swipe_cat=1)&((!variable.lastZerk)|(variable.lastZerk&!variable.lastConvoke)|(variable.lastConvoke&(cooldown.convoke_the_spirits.remains<10&(!set_bonus.tier31_2pc|set_bonus.tier31_2pc&buff.smoldering_frenzy.up))))&((target.time_to_die<fight_remains&target.time_to_die>18)|target.time_to_die=fight_remains)
  if S.Berserk:IsReady() and (not VarAlignCDs and not (not S.FranticMomentum:IsAvailable() and I.WitherbarksBranch:IsEquipped() and EnemiesCount11y == 1) and ((not VarLastZerk) or (VarLastZerk and not VarLastConvoke) or (VarLastConvoke and (S.ConvoketheSpirits:CooldownRemains() < 10 and (not Player:HasTier(31, 2) or Player:HasTier(31, 2) and Player:BuffUp(S.SmolderingFrenzyBuff))))) and ((Target:TimeToDie() < FightRemains and Target:TimeToDie() > 18) or Target:TimeToDie() == FightRemains)) then
    if Cast(S.Berserk, Settings.Feral.GCDasOffGCD.BsInc) then return "berserk cooldown 10"; end
  end
  -- berserk,if=fight_remains<23|(time+118)%%120<30&!talent.frantic_momentum.enabled&(equipped.witherbarks_branch|equipped.ashes_of_the_embersoul)&spell_targets.swipe_cat=1
  if S.Berserk:IsReady() and (FightRemains < 23 or (HL.CombatTime() + 118) % 120 < 30 and not S.FranticMomentum:IsAvailable() and (I.WitherbarksBranch:IsEquipped() or I.AshesoftheEmbersoul:IsEquipped()) and EnemiesCount11y == 1) then
    if Cast(S.Berserk, Settings.Feral.GCDasOffGCD.BsInc) then return "berserk cooldown 12"; end
  end
  -- berserking,if=!variable.align_3minutes|buff.bs_inc.up
  if S.Berserking:IsCastable() and (not VarAlign3Mins or Player:BuffUp(BsInc)) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cooldown 14"; end
  end
  -- potion,if=buff.bs_inc.up|fight_remains<32|(!variable.lastZerk&variable.lastConvoke&cooldown.convoke_the_spirits.remains<10)
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(BsInc) or FightRemains < 32 or (not VarLastZerk and VarLastConvoke and S.ConvoketheSpirits:CooldownRemains() < 10)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldown 16"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=ashes_of_the_embersoul,if=((buff.smoldering_frenzy.up&(!talent.convoke_the_spirits.enabled|cooldown.convoke_the_spirits.remains<10))|!set_bonus.tier31_4pc&(cooldown.convoke_the_spirits.remains=0|!talent.convoke_the_spirits.enabled&buff.bs_inc.up))
    if I.AshesoftheEmbersoul:IsEquippedAndReady() and ((Player:BuffUp(S.SmolderingFrenzyBuff) and (not S.ConvoketheSpirits:IsAvailable() or S.ConvoketheSpirits:CooldownRemains() < 10)) or not Player:HasTier(31, 4) and (S.ConvoketheSpirits:CooldownUp() or not S.ConvoketheSpirits:IsAvailable() and Player:BuffUp(BsInc))) then
      if Cast(I.AshesoftheEmbersoul, nil, Settings.Commons.DisplayStyle.Trinkets) then return "ashes_of_the_embersoul cooldown 18"; end
    end
    -- use_item,name=witherbarks_branch,if=(!talent.convoke_the_spirits.enabled|action.feral_frenzy.ready|!set_bonus.tier31_4pc)&!(trinket.1.is.ashes_of_the_embersoul&trinket.1.cooldown.remains<20|trinket.2.is.ashes_of_the_embersoul&trinket.2.cooldown.remains<20)
    if I.WitherbarksBranch:IsEquippedAndReady() and ((not S.ConvoketheSpirits:IsAvailable() or S.FeralFrenzy:IsReady() or not Player:HasTier(31, 4)) and not (trinket1:ID() == I.AshesoftheEmbersoul:ID() and trinket1:CooldownRemains() < 20 or trinket2:ID() == I.AshesoftheEmbersoul:ID() and trinket2:CooldownRemains() < 20)) then
      if Cast(I.WitherbarksBranch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "witherbarks_branch cooldown 20"; end
    end
    -- use_item,name=mirror_of_fractured_tomorrows,if=(!variable.align_3minutes|buff.bs_inc.up&buff.bs_inc.remains>15|variable.lastConvoke&!variable.lastZerk&cooldown.convoke_the_spirits.remains<1)&(target.time_to_die<fight_remains&target.time_to_die>16|target.time_to_die=fight_remains)
    if I.MirrorofFracturedTomorrows:IsEquippedAndReady() and ((not VarAlign3Mins or Player:BuffUp(BsInc) and Player:BuffRemains(BsInc) > 15 or VarLastConvoke and not VarLastZerk and S.ConvoketheSpirits:CooldownRemains() < 1) and (Target:TimeToDie() < FightRemains and Target:TimeToDie() > 16 or Target:TimeToDie() == FightRemains)) then
      if Cast(I.MirrorofFracturedTomorrows, nil, Settings.Commons.DisplayStyle.Trinkets) then return "mirror_of_fractured_tomorrows cooldown 22"; end
    end
  end
  -- convoke_the_spirits,target_if=max:target.time_to_die,if=fight_remains<5|(buff.smoldering_frenzy.up|!set_bonus.tier31_4pc)&(dot.rip.remains>4-talent.ashamanes_guidance&buff.tigers_fury.up&combo_points<2)&(debuff.dire_fixation.up|!talent.dire_fixation.enabled|spell_targets.swipe_cat>1)&((target.time_to_die<fight_remains&target.time_to_die>5-talent.ashamanes_guidance.enabled)|target.time_to_die=fight_remains)
  if S.ConvoketheSpirits:IsReady() then
    if Everyone.CastTargetIf(S.ConvoketheSpirits, Enemies11y, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfConvokeCD, not IsInMeleeRange) then return "convoke_the_spirits cooldown 24"; end
  end
  -- convoke_the_spirits,if=buff.smoldering_frenzy.up&buff.smoldering_frenzy.remains<5.1-talent.ashamanes_guidance
  if S.ConvoketheSpirits:IsReady() and (Player:BuffUp(S.SmolderingFrenzyBuff) and Player:BuffRemains(S.SmolderingFrenzyBuff) < 5.1 - num(S.AshamanesGuidance:IsAvailable())) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Signature, not IsInMeleeRange) then return "convoke_the_spirits cooldown 26"; end
  end
  -- use_item,name=manic_grieftorch,target_if=max:target.time_to_die,if=energy.deficit>40
  if Settings.Commons.Enabled.Trinkets and I.ManicGrieftorch:IsEquippedAndReady() and (Player:EnergyDeficit() > 40) then
    if Everyone.CastTargetIf(I.ManicGrieftorch, Enemies11y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(40), nil, Settings.Commons.DisplayStyle.Trinkets) then return "manic_grieftorch cooldown 28"; end
  end
  -- use_item,name=mydas_talisman,if=!equipped.ashes_of_the_embersoul&!equipped.witherbarks_branch|((trinket.2.is.witherbarks_branch|trinket.2.is.ashes_of_the_embersoul)&trinket.2.cooldown.remains>20)|((trinket.1.is.witherbarks_branch|trinket.1.is.ashes_of_the_embersoul)&trinket.1.cooldown.remains>20)
  -- use_item,name=bandolier_of_twisted_blades,if=!equipped.ashes_of_the_embersoul&!equipped.witherbarks_branch|((trinket.2.is.witherbarks_branch|trinket.2.is.ashes_of_the_embersoul)&trinket.2.cooldown.remains>20)|((trinket.1.is.witherbarks_branch|trinket.1.is.ashes_of_the_embersoul)&trinket.1.cooldown.remains>20)
  -- use_item,name=fyrakks_tainted_rageheart,if=!equipped.ashes_of_the_embersoul&!equipped.witherbarks_branch|((trinket.2.is.witherbarks_branch|trinket.2.is.ashes_of_the_embersoul)&trinket.2.cooldown.remains>20)|((trinket.1.is.witherbarks_branch|trinket.1.is.ashes_of_the_embersoul)&trinket.1.cooldown.remains>20)
  if (not I.AshesoftheEmbersoul:IsEquipped() and not I.WitherbarksBranch:IsEquipped() or ((trinket2:ID() == I.WitherbarksBranch:ID() or trinket2:ID() == I.AshesoftheEmbersoul:ID()) and trinket2:CooldownRemains() > 20) or ((trinket1:ID() == I.WitherbarksBranch:ID() or trinket1:ID() == I.AshesoftheEmbersoul:ID()) and trinket1:CooldownRemains() > 20)) then
    if I.MydasTalisman:IsEquippedAndReady() then
      if Cast(I.MydasTalisman, nil, Settings.Commons.DisplayStyle.Trinkets) then return "mydas_talisman cooldown 30"; end
    end
    if I.BandolierofTwistedBlades:IsEquippedAndReady() then
      if Cast(I.BandolierofTwistedBlades, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInMeleeRange(5)) then return "bandolier_of_twisted_blades cooldown 32"; end
    end
    if I.FyrakksTaintedRageheart:IsEquippedAndReady() then
      if Cast(I.FyrakksTaintedRageheart, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInMeleeRange(10)) then return "fyrakks_tainted_rageheart cooldown 34"; end
    end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
end

local function APL()
  -- Update Enemies
  local AIRange = mathfloor(1.5 * S.AstralInfluence:TalentRank())
  MeleeRange = 5 + AIRange
  AoERange = 8 + AIRange
  EnemiesMelee = Player:GetEnemiesInMeleeRange(MeleeRange)
  Enemies11y = Player:GetEnemiesInMeleeRange(AoERange)
  if AoEON() then
    EnemiesCountMelee = #EnemiesMelee
    EnemiesCount11y = #Enemies11y
  else
    EnemiesCountMelee = 1
    EnemiesCount11y = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies11y, false)
    end

    -- Combo Points
    ComboPoints = Player:ComboPoints()
    ComboPointsDeficit = Player:ComboPointsDeficit()

    -- Range Stuffs
    IsInMeleeRange = Target:IsInRange(MeleeRange)
    IsInAoERange = Target:IsInRange(AoERange)
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
    local ShouldReturn = Everyone.Interrupt(S.SkullBash, Settings.Feral.OffGCDasOffGCD.SkullBash, InterruptStuns); if ShouldReturn then return ShouldReturn; end
    -- prowl,if=(buff.bs_inc.down|!in_combat)&!buff.prowl.up
    if S.Prowl:IsCastable() and (Player:BuffDown(BsInc) or not Player:AffectingCombat()) then
      if Cast(S.Prowl) then return "prowl main 2"; end
    end
    -- cat_form,if=!buff.cat_form.up
    if S.CatForm:IsCastable() then
      if Cast(S.CatForm) then return "cat_form main 4"; end
    end
    -- invoke_external_buff,name=power_infusion,if=!variable.align_cds|variable.align_cds&buff.bs_inc.up|fight_remains<25
    -- Note: We're not handling external buffs
    -- call_action_list,name=variables
    Variables()
    -- tigers_fury,target_if=min:target.time_to_die,if=!set_bonus.tier31_4pc&talent.convoke_the_spirits.enabled|!buff.tigers_fury.up|energy.deficit>65|set_bonus.tier31_2pc&action.feral_frenzy.ready|target.time_to_die<15&talent.predator.enabled
    if S.TigersFury:IsCastable() and (not Player:HasTier(31, 4) and S.ConvoketheSpirits:IsAvailable() or Player:BuffDown(S.TigersFury) or Player:EnergyDeficit() > 65 or Player:HasTier(31, 2) and S.FeralFrenzy:CooldownUp() or FightRemains < 15 and S.Predator:IsAvailable()) then
      if Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury main 6"; end
    end
    -- rake,target_if=persistent_multiplier>dot.rake.pmultiplier,if=buff.prowl.up|buff.shadowmeld.up
    if S.Rake:IsReady() and (Player:StealthUp(false, true)) then
      if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRakeMain, not IsInAoERange) then return "rake main 8"; end
    end
    -- auto_attack,if=!buff.prowl.up&!buff.shadowmeld.up
    -- natures_vigil,if=spell_targets.swipe_cat>0
    if S.NaturesVigil:IsCastable() then
      if Cast(S.NaturesVigil, Settings.Feral.OffGCDasOffGCD.NaturesVigil) then return "natures_vigil main 10"; end
    end
    -- renewal,if=variable.regrowth
    if S.Renewal:IsCastable() and (VarRegrowth) then
      if Cast(S.Renewal, Settings.Feral.GCDasOffGCD.Renewal) then return "renewal main 12"; end
    end
    -- adaptive_swarm,target=self,if=talent.unbridled_swarm&spell_targets.swipe_cat<=1&dot.adaptive_swarm_heal.stack<4&dot.adaptive_swarm_heal.remains>4
    if S.AdaptiveSwarm:IsReady() and (S.UnbridledSwarm:IsAvailable() and EnemiesCount11y <= 1 and Player:BuffStack(S.AdaptiveSwarmHeal) < 4 and Player:BuffRemains(S.AdaptiveSwarmHeal) > 4) then
      if HR.CastAnnotated(S.AdaptiveSwarm, false, "SELF") then return "adaptive_swarm self main 14"; end
    end
    -- adaptive_swarm,target_if=(!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&dot.adaptive_swarm_damage.stack<3&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight&target.time_to_die>5,if=!talent.unbridled_swarm.enabled|spell_targets.swipe_cat=1
    if S.AdaptiveSwarm:IsReady() and (not S.UnbridledSwarm:IsAvailable() or EnemiesCount11y == 1) then
      if Everyone.CastCycle(S.AdaptiveSwarm, Enemies11y, EvaluateCycleAdaptiveSwarm, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm main 16"; end
    end
    -- adaptive_swarm,target_if=max:(1+dot.adaptive_swarm_damage.stack)*dot.adaptive_swarm_damage.stack<3*time_to_die,if=dot.adaptive_swarm_damage.stack<3&talent.unbridled_swarm.enabled&spell_targets.swipe_cat>1
    if S.AdaptiveSwarm:IsReady() and (S.UnbridledSwarm:IsAvailable() and EnemiesCount11y > 1) then
      if Everyone.CastTargetIf(S.AdaptiveSwarm, Enemies11y, "max", EvaluateTargetIfFilterAdaptiveSwarm, EvaluateTargetIfAdaptiveSwarm, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm main 18"; end
    end
    -- call_action_list,name=cooldown,if=(time>3|!talent.dire_fixation.enabled|debuff.dire_fixation.up&combo_points<4|spell_targets.swipe_cat>1)&!(spell_targets=1&talent.convoke_the_spirits.enabled)
    if CDsON() and ((HL.CombatTime() > 3 or not S.DireFixation:IsAvailable() or Target:DebuffUp(S.DireFixationDebuff) and ComboPoints < 4 or EnemiesCount11y > 1) and not (EnemiesCount11y == 1 and S.ConvoketheSpirits:IsAvailable())) then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cooldown,if=dot.rip.ticking
    if CDsON() and Target:DebuffUp(S.RipDebuff) then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    -- feral_frenzy,target_if=max:target.time_to_die,if=((combo_points<3|time<10&combo_points<4)&(!talent.dire_fixation.enabled|debuff.dire_fixation.up|spell_targets.swipe_cat>1)&(target.time_to_die<fight_remains&target.time_to_die>6|target.time_to_die=fight_remains))&!(spell_targets=1&talent.convoke_the_spirits.enabled)
    if S.FeralFrenzy:IsReady() then
      if Everyone.CastTargetIf(S.FeralFrenzy, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfFeralFrenzy, not IsInMeleeRange) then return "feral_frenzy main 20"; end
    end
    -- feral_frenzy,if=combo_points<3&debuff.dire_fixation.up&dot.rip.ticking&(spell_targets=1&talent.convoke_the_spirits.enabled)
    if S.FeralFrenzy:IsReady() and (ComboPoints < 3 and Target:DebuffUp(S.DireFixationDebuff) and Target:DebuffUp(S.RipDebuff) and (EnemiesCount11y == 1 and S.ConvoketheSpirits:IsAvailable())) then
      if Cast(S.FeralFrenzy, nil, nil, not IsInAoERange) then return "feral_frenzy main 21"; end
    end
    -- ferocious_bite,target_if=max:target.time_to_die,if=buff.apex_predators_craving.up&(spell_targets.swipe_cat=1|!talent.primal_wrath.enabled|!buff.sabertooth.up)&!(variable.need_bt&active_bt_triggers=2)
    if S.FerociousBite:IsReady() and (Player:BuffUp(S.ApexPredatorsCravingBuff) and (EnemiesCount11y == 1 or not S.PrimalWrath:IsAvailable() or Player:BuffDown(S.SabertoothBuff)) and not (VarNeedBT and CountActiveBtTriggers() == 2)) then
      if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterTTD, nil, not IsInMeleeRange) then return "ferocious_bite main 22"; end
    end
    -- run_action_list,name=berserk,if=buff.bs_inc.up
    if Player:BuffUp(BsInc) then
      local ShouldReturn = Berserk(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Berserk()"; end
    end
    -- wait,sec=combo_points=5,if=combo_points=4&buff.predator_revealed.react&energy.deficit>40&spell_targets.swipe_cat=1
    if ComboPoints == 4 and Player:BuffUp(S.PredatorRevealedBuff) and Player:EnergyDeficit() > 40 and EnemiesCount11y == 1 then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Finisher()"; end
    end
    -- call_action_list,name=finisher,if=combo_points>=4
    if ComboPoints >= 4 then
      local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_builder,if=spell_targets.swipe_cat>1&combo_points<4
    if (EnemiesCount11y > 1 and ComboPoints < 4) then
      local ShouldReturn = AoeBuilder(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=builder,if=!buff.bs_inc.up&spell_targets.swipe_cat=1&combo_points<4
    if Player:BuffDown(BsInc) and EnemiesCount11y == 1 and ComboPoints < 4 then
      local ShouldReturn = Builder(); if ShouldReturn then return ShouldReturn; end
    end
    -- regrowth,if=energy<25&buff.predatory_swiftness.up&!buff.clearcasting.up&variable.regrowth
    if S.Regrowth:IsReady() and VarRegrowth and (Player:Energy() < 25 and Player:BuffUp(S.PredatorySwiftnessBuff) and Player:BuffDown(S.Clearcasting)) then
      if Cast(S.Regrowth, Settings.Feral.GCDasOffGCD.Regrowth) then return "regrowth main 24"; end
    end
    -- Pool if nothing else to do
    if (true) then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool Energy"; end
    end
  end
end

local function OnInit()
  S.RipDebuff:RegisterAuraTracking()

  HR.Print("Feral Druid rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(103, APL, OnInit)
