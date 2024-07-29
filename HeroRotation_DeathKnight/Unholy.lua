--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL          = HeroLib
local Cache       = HeroCache
local Unit        = HL.Unit
local Player      = Unit.Player
local Target      = Unit.Target
local Boss        = Unit.Boss
local Pet         = Unit.Pet
local Spell       = HL.Spell
local Item        = HL.Item
-- HeroRotation
local HR          = HeroRotation
local Cast        = HR.Cast
local CDsON       = HR.CDsON
local AoEON       = HR.AoEON
-- Num/Bool Helper Functions
local num         = HR.Commons.Everyone.num
local bool        = HR.Commons.Everyone.bool
-- lua
local mathmax     = math.max
local tableinsert = table.insert
local GetTime     = GetTime

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Unholy
local I = Item.DeathKnight.Unholy

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.Fyralath:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  CommonsDS = HR.GUISettings.APL.DeathKnight.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.DeathKnight.CommonsOGCD,
  Unholy = HR.GUISettings.APL.DeathKnight.Unholy
}

--- ===== Rotation Variables =====
local VarSTPlanning
local VarAddsRemain
local VarApocTiming
local VarPopWounds
local VarPoolingRunicPower
local VarSpendRP
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Duration, VarTrinket2Duration
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority, VarDamageTrinketPriority
local VarAbomActive, VarAbomRemains
local VarApocGhoulActive, VarApocGhoulRemains
local VarArmyGhoulActive, VarArmyGhoulRemains
local VarGargActive, VarGargRemains
local WoundSpender = (S.ClawingShadows:IsAvailable()) and S.ClawingShadows or S.ScourgeStrike
local AnyDnD = (S.Defile:IsAvailable()) and S.Defile or S.DeathAndDecay
local FesterStacks
local EnemiesMelee, EnemiesMeleeCount, ActiveEnemies
local Enemies10ySplash, Enemies10ySplashCount
local EnemiesWithoutVP
local BossFightRemains = 11111
local FightRemains = 11111
local Ghoul = HL.GhoulTable

--- ===== Trinket Item Objects =====
local Trinket1, Trinket2 = Player:GetTrinketItems()

--- ===== Trinket Variables (from Precombat) =====
local function SetTrinketVariables()
  VarTrinket1ID = Trinket1:ID()
  VarTrinket2ID = Trinket2:ID()

  local Trinket1Spell = Trinket1:OnUseSpell()
  VarTrinket1Range = (Trinket1Spell and Trinket1Spell.MaximumRange > 0 and Trinket1Spell.MaximumRange <= 100) and Trinket1Spell.MaximumRange or 100
  local Trinket2Spell = Trinket2:OnUseSpell()
  VarTrinket2Range = (Trinket2Spell and Trinket2Spell.MaximumRange > 0 and Trinket2Spell.MaximumRange <= 100) and Trinket2Spell.MaximumRange or 100

  VarTrinket1CD = Trinket1:Cooldown()
  VarTrinket2CD = Trinket2:Cooldown()

  VarTrinket1Buffs = Trinket1:HasUseBuff() or VarTrinket1ID == I.MirrorofFracturedTomorrows:ID()
  VarTrinket2Buffs = Trinket2:HasUseBuff() or VarTrinket2ID == I.MirrorofFracturedTomorrows:ID()

  VarTrinket1Duration = (VarTrinket1ID == I.MirrorofFracturedTomorrows:ID()) and 20 or Trinket1:BuffDuration()
  VarTrinket2Duration = (VarTrinket2ID == I.MirrorofFracturedTomorrows:ID()) and 20 or Trinket2:BuffDuration()

  VarTrinket1Sync = 0.5
  if VarTrinket1Buffs and (S.Apocalypse:IsAvailable() and VarTrinket1CD % 30 == 0 or S.DarkTransformation:IsAvailable() and VarTrinket1CD % 45 == 0) or VarTrinket1ID == I.TreacherousTransmitter:ID() then
    VarTrinket1Sync = 1
  end

  VarTrinket2Sync = 0.5
  if VarTrinket2Buffs and (S.Apocalypse:IsAvailable() and VarTrinket2CD % 30 == 0 or S.DarkTransformation:IsAvailable() and VarTrinket2CD % 45 == 0) or VarTrinket2ID == I.TreacherousTransmitter:ID() then
    VarTrinket2Sync = 1
  end

  VarTrinketPriority = 1
  -- Note: Using the below buff durations to avoid potential divide by zero errors.
  local T1BuffDuration = (VarTrinket1Duration > 0) and VarTrinket1Duration or 1
  local T2BuffDuration = (VarTrinket2Duration > 0) and VarTrinket2Duration or 1
  if not VarTrinket1Buffs and VarTrinket2Buffs and (Trinket2:HasCooldown() or not Trinket1:HasCooldown()) or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDuration) * (VarTrinket2Sync)) > ((VarTrinket1CD / T1BuffDuration) * (VarTrinket1Sync) * (1 + ((Trinket1:Level() - Trinket2:Level()) / 100))) then
    VarTrinketPriority = 2
  end

  VarDamageTrinketPriority = 1
  if not VarTrinket1Buffs and not VarTrinket2Buffs and Trinket2:Level() >= Trinket1:Level() then
    VarDamageTrinketPriority = 2
  end
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  Trinket1, Trinket2 = Player:GetTrinketItems()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  AnyDnD = (S.Defile:IsAvailable()) and S.Defile or S.DeathAndDecay
  SetTrinketVariables()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function DeathStrikeHeal()
  return (Settings.General.SoloMode and (Player:HealthPercentage() < Settings.Commons.UseDeathStrikeHP or Player:HealthPercentage() < Settings.Commons.UseDarkSuccorHP and Player:BuffUp(S.DeathStrikeBuff)))
end

local function UnitsWithoutVP(enemies)
  local WithoutVPCount = 0
  for _, CycleUnit in pairs(enemies) do
    if CycleUnit:DebuffDown(S.VirulentPlagueDebuff) then
      WithoutVPCount = WithoutVPCount + 1
    end
  end
  return WithoutVPCount
end

local function AddsFightRemains(enemies)
  local NonBossEnemies = {}
  for k in pairs(enemies) do
    if not Unit:IsInBossList(enemies[k]["UnitNPCID"]) then
      tableinsert(NonBossEnemies, enemies[k])
    end
  end
  return HL.FightRemains(NonBossEnemies)
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterFWStack(TargetUnit)
  -- target_if=min:debuff.festering_wound.stack
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfFesteringStrikeAoE(TargetUnit)
  -- if=cooldown.apocalypse.remains<gcd&debuff.festering_wound.stack=0|buff.festering_scythe.react
  return S.Apocalypse:CooldownRemains() < Player:GCD() and TargetUnit:DebuffDown(S.FesteringWoundDebuff) or Player:BuffUp(S.FesteringScytheBuff)
end

local function EvaluateTargetIfFesteringStrikeAoE2(TargetUnit)
  -- if=debuff.festering_wound.stack<4
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 4
end

local function EvaluateTargetIfVileContagionCDsShared(TargetUnit)
  -- if=variable.adds_remain&(debuff.festering_wound.stack=6&(defile.ticking|death_and_decay.ticking|cooldown.any_dnd.remains<3)|raid_event.adds.exists&raid_event.adds.remains<=11&raid_event.adds.remains>5|buff.death_and_decay.up&debuff.festering_wound.stack>=4|cooldown.any_dnd.remains<3&debuff.festering_wound.stack>=4)
  -- Note: Variable checked before CastTargetIf.
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) == 6 and (Player:BuffUp(S.DefileBuff) or Player:BuffUp(S.DeathAndDecayBuff) or AnyDnD:CooldownRemains() < 3) or Player:BuffUp(S.DeathAndDecayBuff) and TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4 or AnyDnD:CooldownRemains() < 3 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4
end

local function EvaluateTargetIfWoundSpenderAoE(TargetUnit)
  -- if=debuff.festering_wound.stack>=1&cooldown.apocalypse.remains>gcd
  return TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 1 and S.Apocalypse:CooldownRemains() > Player:GCD()
end

--- ===== CastCycle Functions =====
local function EvaluateCycleOutbreakCDs(TargetUnit)
  -- target_if=target.time_to_die>dot.virulent_plague.remains,if=(dot.virulent_plague.refreshable|talent.superstrain&(dot.frost_fever.refreshable|dot.blood_plague.refreshable))&(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains>15%((3*talent.superstrain)+(2*talent.ebon_fever)+(2*talent.plaguebringer)))&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>15%((3*talent.superstrain)+(2*talent.ebon_fever)+(2*talent.plaguebringer)))
  return (TargetUnit:TimeToDie() > TargetUnit:DebuffRemains(S.VirulentPlagueDebuff)) and ((TargetUnit:DebuffRefreshable(S.VirulentPlagueDebuff) or S.Superstrain:IsAvailable() and (TargetUnit:DebuffRefreshable(S.FrostFeverDebuff) or TargetUnit:DebuffRefreshable(S.BloodPlagueDebuff))) and (not S.UnholyBlight:IsAvailable() or S.UnholyBlight:IsAvailable() and S.DarkTransformation:CooldownRemains() > 15 / ((3 * num(S.Superstrain:IsAvailable())) + (2 * num(S.EbonFever:IsAvailable())) + (2 * num(S.Plaguebringer:IsAvailable())))) and (not S.RaiseAbomination:IsAvailable() or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 15 / ((3 * num(S.Superstrain:IsAvailable())) + (2 * num(S.EbonFever:IsAvailable())) + (2 * num(S.Plaguebringer:IsAvailable())))))
end

local function EvaluateCycleOutbreakCDsSan(TargetUnit)
  -- target_if=target.time_to_die>dot.virulent_plague.remains,if=(pet.abomination.remains<15&dot.virulent_plague.refreshable|talent.morbidity&buff.infliction_of_sorrow.up&talent.superstrain&dot.frost_fever.refreshable&dot.blood_plague.refreshable)&(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains>15%((3*talent.superstrain)+(2*talent.ebon_fever)+(2*talent.plaguebringer)))&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>15%((3*talent.superstrain)+(2*talent.ebon_fever)+(2*talent.plaguebringer)))
  return (TargetUnit:TimeToDie() > TargetUnit:DebuffRemains(S.VirulentPlagueDebuff)) and ((VarAbomRemains < 15 and TargetUnit:DebuffRefreshable(S.VirulentPlagueDebuff) or S.Morbidity:IsAvailable() and Player:BuffUp(S.InflictionofSorrowBuff) and S.Superstrain:IsAvailable() and TargetUnit:DebuffRefreshable(S.FrostFeverDebuff) and TargetUnit:DebuffRefreshable(S.BloodPlagueDebuff)) and (not S.UnholyBlight:IsAvailable() or S.UnholyBlight:IsAvailable() and S.DarkTransformation:CooldownRemains() > 15 / ((3 * num(S.Superstrain:IsAvailable())) + (2 * num(S.EbonFever:IsAvailable())) + (2 * num(S.Plaguebringer:IsAvailable())))) and (not S.RaiseAbomination:IsAvailable() or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 15 / ((3 * num(S.Superstrain:IsAvailable())) + (2 * num(S.EbonFever:IsAvailable())) + (2 * num(S.Plaguebringer:IsAvailable())))))
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- raise_dead
  if S.RaiseDead:IsCastable() then
    if Settings.Unholy.RaiseDeadCastLeft then
      if HR.CastLeft(S.RaiseDead) then return "raise_dead precombat 2 left"; end
    else
      if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead precombat 2 displaystyle"; end
    end
  end
  -- army_of_the_dead,precombat_time=2
  if S.ArmyoftheDead:IsReady() and not Settings.Commons.DisableAotD then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyOfTheDead) then return "army_of_the_dead precombat 4"; end
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|trinket.1.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|trinket.2.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_1_duration,op=setif,value=20,value_else=trinket.1.proc.any_dps.duration,condition=trinket.1.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_2_duration,op=setif,value=20,value_else=trinket.2.proc.any_dps.duration,condition=trinket.2.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(talent.apocalypse&trinket.1.cooldown.duration%%cooldown.apocalypse.duration=0|talent.dark_transformation&trinket.1.cooldown.duration%%cooldown.dark_transformation.duration=0)|trinket.1.is.treacherous_transmitter
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(talent.apocalypse&trinket.2.cooldown.duration%%cooldown.apocalypse.duration=0|talent.dark_transformation&trinket.2.cooldown.duration%%cooldown.dark_transformation.duration=0)|trinket.2.is.treacherous_transmitter
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs&(trinket.2.has_cooldown|!trinket.1.has_cooldown)|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync)*(1+((trinket.1.ilvl-trinket.2.ilvl)%100)))
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  -- Note: Moved the above variable definitions to initial profile load, SPELLS_CHANGED, and PLAYER_EQUIPMENT_CHANGED.
  -- Manually added: outbreak
  if S.Outbreak:IsReady() then
    if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak precombat 6"; end
  end
  -- Manually added: festering_strike if in melee range
  if FesteringAction:IsReady() then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(5)) then return "festering_strike precombat 8"; end
  end
end

local function AoE()
  -- any_dnd,if=!buff.death_and_decay.up&(!talent.bursting_sores|death_knight.fwounded_targets=active_enemies|death_knight.fwounded_targets>=8|raid_event.adds.exists&raid_event.adds.remains<=11&raid_event.adds.remains>5)
  if AnyDnD:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (not S.BurstingSores:IsAvailable() or S.FesteringWoundDebuff:AuraActiveCount() == ActiveEnemies or S.FesteringWoundDebuff:AuraActiveCount() >= 8)) then
    if Cast(AnyDnD, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "any_dnd aoe 2"; end
  end
  -- epidemic,if=!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe 4"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=cooldown.apocalypse.remains<gcd&debuff.festering_wound.stack=0|buff.festering_scythe.react
  if FesteringAction:IsReady() then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeAoE, not Target:IsInMeleeRange(5)) then return "festering_strike aoe 6"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=1&cooldown.apocalypse.remains>gcd
  if WoundSpender:IsReady() then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfWoundSpenderAoE, not Target:IsInMeleeRange(5)) then return "wound_spender aoe 8"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=debuff.festering_wound.stack<4
  if FesteringAction:IsReady() then
    if Everyone.CastTargetIf(FesteringAction, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeAoE2, not Target:IsInMeleeRange(5)) then return "festering_strike aoe 10"; end
  end
end

local function AoEBurst()
  -- defile,if=!defile.ticking
  if S.Defile:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.Defile, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "defile aoe_burst 2"; end
  end
  -- epidemic,if=!variable.pooling_runic_power&(active_enemies>=6&!talent.bursting_sores|talent.bursting_sores&death_knight.fwounded_targets!=active_enemies&death_knight.fwounded_targets<6|!talent.bursting_sores&runic_power.deficit<30|buff.sudden_doom.react)
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower and (ActiveEnemies >= 6 and not S.BurstingSores:IsAvailable() or S.BurstingSores:IsAvailable() and S.FesteringWoundDebuff:AuraActiveCount() < 6 or not S.BurstingSores:IsAvailable() and Player:RunicPowerDeficit() < 30 or Player:BuffUp(S.SuddenDoomBuff))) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_burst 4"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=1
  if WoundSpender:IsReady() then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfWoundSpenderAoEBurst, not Target:IsInMeleeRange(5)) then return "wound_spender aoe_burst 6"; end
  end
  -- festering_strike,if=buff.festering_scythe.react
  if FesteringAction:IsReady() then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(14)) then return "festering_scythe aoe_burst 8"; end
  end
  -- epidemic,if=!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_burst 10"; end
  end
  -- wound_spender
  if WoundSpender:IsReady() then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender aoe_burst 12"; end
  end
end

local function CDs()
  -- dark_transformation,if=(variable.st_planning|variable.adds_remain)&(cooldown.apocalypse.remains<8|!talent.apocalypse|active_enemies>=1)
  if S.DarkTransformation:IsCastable() and ((VarSTPlanning or VarAddsRemain) and (S.Apocalypse:CooldownRemains() < 8 or not S.Apocalypse:IsAvailable() or ActiveEnemies >= 1)) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cds 2"; end
  end
  -- unholy_assault,if=(variable.st_planning|variable.adds_remain)&(cooldown.apocalypse.remains<gcd*2|!talent.apocalypse|active_enemies>=2&buff.dark_transformation.up)
  if S.UnholyAssault:IsCastable() and ((VarSTPlanning or VarAddsRemain) and (S.Apocalypse:CooldownRemains() < Player:GCD() * 2 or not S.Apocalypse:IsAvailable() or ActiveEnemies >= 2 and Pet:BuffUp(S.DarkTransformation))) then
    if Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault, nil, not Target:IsInMeleeRange(5)) then return "unholy_assault cds 4"; end
  end
  -- apocalypse,if=(variable.st_planning|variable.adds_remain)
  if S.Apocalypse:IsReady() and (VarSTPlanning or VarAddsRemain) then
    if Cast(S.Apocalypse, Settings.Unholy.GCDasOffGCD.Apocalypse, nil, not Target:IsInMeleeRange(5)) then return "apocalypse cds 6"; end
  end
  -- outbreak,target_if=target.time_to_die>dot.virulent_plague.remains,if=(dot.virulent_plague.refreshable|talent.superstrain&(dot.frost_fever.refreshable|dot.blood_plague.refreshable))&(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains>15%((3*talent.superstrain)+(2*talent.ebon_fever)+(2*talent.plaguebringer)))&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>15%((3*talent.superstrain)+(2*talent.ebon_fever)+(2*talent.plaguebringer)))
  if S.Outbreak:IsReady() then
    if Everyone.CastCycle(S.Outbreak, EnemiesMelee, EvaluateCycleOutbreakCDs, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak cds 8"; end
  end
  -- abomination_limb,if=(variable.st_planning|variable.adds_remain)&(active_enemies>=2|!buff.sudden_doom.react&buff.festermight.up&debuff.festering_wound.stack<=2)
  if S.AbominationLimb:IsCastable() and ((VarSTPlanning or VarAddsRemain) and (ActiveEnemies >= 2 or Player:BuffDown(S.SuddenDoomBuff) and Player:BuffUp(S.FestermightBuff) and FesterStacks <= 2)) then
    if Cast(S.AbominationLimb, Settings.Unholy.GCDasOffGCD.AbominationLimb, nil, not Target:IsInRange(20)) then return "abomination_limb cds 10"; end
  end
end

local function CDsSan()
  -- dark_transformation,if=active_enemies>=1&(variable.st_planning|variable.adds_remain)&(talent.apocalypse&(pet.apoc_ghoul.active|active_enemies>=2)|!talent.apocalypse)
  if S.DarkTransformation:IsCastable() and (ActiveEnemies >= 1 and (VarSTPlanning or VarAddsRemain) and (S.Apocalypse:IsAvailable() and (VarApocGhoulActive or ActiveEnemies >= 2) and not S.Apocalypse:IsAvailable())) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cds_san 2"; end
  end
  -- unholy_assault,if=(variable.st_planning|variable.adds_remain)&(buff.dark_transformation.up&buff.dark_transformation.remains<12)
  if S.UnholyAssault:IsCastable() and ((VarSTPlanning or VarAddsRemain) and (Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < 12)) then
    if Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault, nil, not Target:IsInMeleeRange(5)) then return "unholy_assault cds_san 4"; end
  end
  -- apocalypse,if=(variable.st_planning|variable.adds_remain)&(debuff.festering_wound.stack>=3|active_enemies>=2)
  if S.Apocalypse:IsReady() and ((VarSTPlanning or VarAddsRemain) and (FesterStacks >= 3 or ActiveEnemies >= 2)) then
    if Cast(S.Apocalypse, Settings.Unholy.GCDasOffGCD.Apocalypse, nil, not Target:IsInMeleeRange(5)) then return "apocalypse cds_san 6"; end
  end
  -- outbreak,target_if=target.time_to_die>dot.virulent_plague.remains,if=(pet.abomination.remains<15&dot.virulent_plague.refreshable|talent.morbidity&buff.infliction_of_sorrow.up&talent.superstrain&dot.frost_fever.refreshable&dot.blood_plague.refreshable)&(!talent.unholy_blight|talent.unholy_blight&cooldown.dark_transformation.remains>15%((3*talent.superstrain)+(2*talent.ebon_fever)+(2*talent.plaguebringer)))&(!talent.raise_abomination|talent.raise_abomination&cooldown.raise_abomination.remains>15%((3*talent.superstrain)+(2*talent.ebon_fever)+(2*talent.plaguebringer)))
  if S.Outbreak:IsReady() then
    if Everyone.CastCycle(S.Outbreak, EnemiesMelee, EvaluateCycleOutbreakCDsSan, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak cds_san 8"; end
  end
  -- abomination_limb,if=active_enemies>=1&(variable.st_planning|variable.adds_remain)&(active_enemies>=2|!buff.dark_transformation.up&!buff.sudden_doom.react&buff.festermight.up&debuff.festering_wound.stack<=2)
  if S.AbominationLimb:IsCastable() and (ActiveEnemies >= 1 and (VarSTPlanning or VarAddsRemain) and (ActiveEnemies >= 2 or Pet:BuffDown(S.DarkTransformation) and Player:BuffDown(S.SuddenDoomBuff) and Player:BuffUp(S.FestermightBuff) and FesterStacks <= 2)) then
    if Cast(S.AbominationLimb, Settings.Unholy.GCDasOffGCD.AbominationLimb, nil, not Target:IsInRange(20)) then return "abomination_limb cds_san 10"; end
  end
end

local function CDsShared()
  -- potion,if=active_enemies>=1&(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(buff.dark_transformation.up&30>=buff.dark_transformation.remains|pet.army_ghoul.active&pet.army_ghoul.remains<=30|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=30|pet.abomination.active&pet.abomination.remains<=30)|fight_remains<=30
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected then
      if PotionSelected:IsReady() and (ActiveEnemies >= 1 and (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (Pet:BuffUp(S.DarkTransformation) and 30 >= Pet:BuffRemains(S.DarkTransformation) or VarArmyGhoulActive and VarArmyGhoulRemains <= 30 or VarApocGhoulActive and VarApocGhoulRemains <= 30 or VarAbomActive and VarAbomRemains <= 30) or BossFightRemains <= 30) then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds_shared 2"; end
      end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=active_enemies>=1&(variable.st_planning|variable.adds_remain)&(pet.gargoyle.active&pet.gargoyle.remains<=22|!talent.summon_gargoyle&talent.army_of_the_dead&(talent.raise_abomination&pet.abomination.active&pet.abomination.remains<18|!talent.raise_abomination&pet.army_ghoul.active&pet.army_ghoul.remains<=18)|!talent.summon_gargoyle&!talent.army_of_the_dead&buff.dark_transformation.up|!talent.summon_gargoyle&buff.dark_transformation.up|!pet.gargoyle.active&cooldown.summon_gargoyle.remains+10>cooldown.invoke_external_buff_power_infusion.duration|active_enemies>=3&(buff.dark_transformation.up|death_and_decay.ticking))
  -- Note: Not handling external buffs.
  -- army_of_the_dead,if=(variable.st_planning|variable.adds_remain)&(talent.commander_of_the_dead&cooldown.dark_transformation.remains<5|!talent.commander_of_the_dead&active_enemies>=1)|fight_remains<35
  if S.ArmyoftheDead:IsReady() and not Settings.Commons.DisableAotD and ((VarSTPlanning or VarAddsRemain) and (S.CommanderoftheDead:IsAvailable() and S.DarkTransformation:CooldownRemains() < 5 or not S.CommanderoftheDead:IsAvailable() and ActiveEnemies >= 1) or BossFightRemains < 35) then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyOfTheDead) then return "army_of_the_dead cds_shared 4"; end
  end
  -- raise_abomination,if=(variable.st_planning|variable.adds_remain)&(talent.commander_of_the_dead&cooldown.dark_transformation.remains<gcd*2|!talent.commander_of_the_dead&active_enemies>=1)|fight_remains<30
  if S.RaiseAbomination:IsCastable() and ((VarSTPlanning or VarAddsRemain) and (S.CommanderoftheDead:IsAvailable() and S.DarkTransformation:CooldownRemains() < Player:GCD() * 2 or not S.CommanderoftheDead:IsAvailable() and ActiveEnemies >= 1) or BossFightRemains < 30) then
    if Cast(S.RaiseAbomination, Settings.Unholy.GCDasOffGCD.RaiseAbomination) then return "raise_abomination cds_shared 6"; end
  end
  -- summon_gargoyle,use_off_gcd=1,if=(variable.st_planning|variable.adds_remain)&(buff.commander_of_the_dead.up|!talent.commander_of_the_dead&active_enemies>=1)
  if S.SummonGargoyle:IsReady() and ((VarSTPlanning or VarAddsRemain) and (Player:BuffUp(S.CommanderoftheDeadBuff) or not S.CommanderoftheDead:IsAvailable() and ActiveEnemies >= 1)) then
    if Cast(S.SummonGargoyle, Settings.Unholy.GCDasOffGCD.SummonGargoyle) then return "summon_gargoyle cds_shared 8"; end
  end
  -- vile_contagion,target_if=max:debuff.festering_wound.stack,if=variable.adds_remain&(debuff.festering_wound.stack=6&(defile.ticking|death_and_decay.ticking|cooldown.any_dnd.remains<3)|raid_event.adds.exists&raid_event.adds.remains<=11&raid_event.adds.remains>5|buff.death_and_decay.up&debuff.festering_wound.stack>=4|cooldown.any_dnd.remains<3&debuff.festering_wound.stack>=4)
  if S.VileContagion:IsReady() and (VarAddsRemain) then
    if Everyone.CastTargetIf(S.VileContagion, Enemies10ySplash, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfVileContagionCDsShared, not Target:IsSpellInRange(S.VileContagion)) then return "vile_contagion cds_shared 10"; end
  end
end

local function Cleave()
  -- any_dnd,if=!buff.death_and_decay.up
  if AnyDnD:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(AnyDnD, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "any_dnd cleave 2"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&talent.improved_death_coil
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and S.ImprovedDeathCoil:IsAvailable()) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil cleave 4"; end
  end
  -- festering_strike,if=!variable.pop_wounds&debuff.festering_wound.stack<4|buff.festering_scythe.react
  if FesteringAction:IsReady() and (not VarPopWounds and FesterStacks < 4 or Player:BuffUp(S.FesteringScytheBuff)) then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(5)) then return "festering_strike cleave 6"; end
  end
  -- wound_spender,if=variable.pop_wounds
  if WoundSpender:IsReady() and (VarPopWounds) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender cleave 8"; end
  end
  -- epidemic,if=!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic cleave 10"; end
  end
end

local function Racials()
  -- arcane_torrent,if=runic_power<20&rune<2
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPower() < 20 and Player:Rune() < 2) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent racials 2"; end
  end
  -- blood_fury,if=(buff.blood_fury.duration+3>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=buff.blood_fury.duration+3|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.blood_fury.duration+3|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.blood_fury.duration+3
  if S.BloodFury:IsCastable() and ((S.BloodFury:BaseDuration() + 3 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= S.BloodFury:BaseDuration() + 3 or VarApocGhoulActive and VarApocGhoulRemains <= S.BloodFury:BaseDuration() + 3 or ActiveEnemies >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or BossFightRemains <= S.BloodFury:BaseDuration() + 3) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury racials 4"; end
  end
  -- berserking,if=(buff.berserking.duration+3>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=buff.berserking.duration+3|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.berserking.duration+3|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.berserking.duration+3
  if S.Berserking:IsCastable() and ((S.Berserking:BaseDuration() + 3 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= S.Berserking:BaseDuration() + 3 or VarApocGhoulActive and VarApocGhoulRemains <= S.Berserking:BaseDuration() + 3 or ActiveEnemies >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or BossFightRemains <= S.Berserking:BaseDuration() + 3) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking racials 6"; end
  end
  -- lights_judgment,if=buff.unholy_strength.up&(!talent.festermight|buff.festermight.remains<target.time_to_die|buff.unholy_strength.remains<target.time_to_die)
  if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff) and (not S.Festermight:IsAvailable() or Player:BuffRemains(S.FestermightBuff) < Target:TimeToDie() or Player:BuffRemains(S.UnholyStrengthBuff) < Target:TimeToDie())) then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
  end
  -- ancestral_call,if=(18>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=18|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=18|active_enemies>=2&death_and_decay.ticking)|fight_remains<=18
  if S.AncestralCall:IsCastable() and ((18 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= 18 or VarApocGhoulActive and VarApocGhoulRemains <= 18 or ActiveEnemies >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or BossFightRemains <= 18) then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
  end
  -- arcane_pulse,if=active_enemies>=2|(rune.deficit>=5&runic_power.deficit>=60)
  if S.ArcanePulse:IsCastable() and (ActiveEnemies >= 2 or (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
    if Cast(S.ArcanePulse, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 12"; end
  end
  -- fireblood,if=(buff.fireblood.duration+3>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=buff.fireblood.duration+3|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.fireblood.duration+3|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.fireblood.duration+3
  if S.Fireblood:IsCastable() and ((S.Fireblood:BaseDuration() + 3 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= S.Fireblood:BaseDuration() + 3 or VarApocGhoulActive and VarApocGhoulRemains <= S.Fireblood:BaseDuration() + 3 or ActiveEnemies >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or BossFightRemains <= S.Fireblood:BaseDuration() + 3) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood racials 14"; end
  end
  -- bag_of_tricks,if=active_enemies=1&(buff.unholy_strength.up|fight_remains<5)
  if S.BagofTricks:IsCastable() and (ActiveEnemies == 1 and (Player:BuffUp(S.UnholyStrengthBuff) or BossFightRemains < 5)) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks racials 16"; end
  end
end

local function SanFishing()
  -- antimagic_shell,if=death_knight.ams_absorb_percent>0&runic_power<40
  if S.AntiMagicShell:IsCastable() and Settings.Commons.UseAMSAMZOffensively and (Settings.Unholy.AMSAbsorbPercent > 0 and Player:RunicPower() < 40) then
    if Cast(S.AntiMagicShell, Settings.CommonsOGCD.GCDasOffGCD.AntiMagicShell) then return "antimagic_shell san_fishing 2"; end
  end
  -- any_dnd,if=!buff.death_and_decay.up&!buff.vampiric_strike.react
  if AnyDnD:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and Player:BuffDown(S.VampiricStrikeBuff)) then
    if Cast(AnyDnD, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "any_dnd san_fishing 4"; end
  end
  -- death_coil,if=buff.sudden_doom.react&talent.doomed_bidding
  if S.DeathCoil:IsReady() and (Player:BuffUp(S.SuddenDoomBuff) and S.DoomedBidding:IsAvailable()) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_fishing 6"; end
  end
  -- soul_reaper,if=target.health.pct<=35&fight_remains>5
  if S.SoulReaper:IsReady() and (Target:HealthPercentage() <= 35 and FightRemains > 5) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper san_fishing 8"; end
  end
  -- death_coil,if=!buff.vampiric_strike.react
  if S.DeathCoil:IsReady() and (Player:BuffDown(S.VampiricStrikeBuff)) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_fishing 10"; end
  end
  -- wound_spender,if=(debuff.festering_wound.stack>=3-pet.abomination.active&cooldown.apocalypse.remains>variable.apoc_timing)|buff.vampiric_strike.react
  if WoundSpender:IsReady() and ((FesterStacks >= 3 - num(VarAbomActive) and S.Apocalypse:CooldownRemains() > VarApocTiming) or Player:BuffUp(S.VampiricStrikeBuff)) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_fishing 12"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<3-pet.abomination.active
  if FesteringAction:IsReady() and (FesterStacks < 3 - num(VarAbomActive)) then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(5)) then return "festering_strike san_fishing 14"; end
  end
end

local function SanST()
  -- wound_spender,if=buff.essence_of_the_blood_queen.remains<3&buff.vampiric_strike.react|talent.gift_of_the_sanlayn&buff.dark_transformation.up&buff.dark_transformation.remains<gcd
  if WoundSpender:IsReady() and (Player:BuffRemains(S.EssenceoftheBloodQueenBuff) < 3 and Player:BuffUp(S.VampiricStrikeBuff) or S.GiftoftheSanlayn:IsAvailable() and Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < Player:GCD()) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_st 2"; end
  end
  -- death_coil,if=buff.sudden_doom.react&buff.gift_of_the_sanlayn.remains&buff.essence_of_the_blood_queen.stack>=3&(talent.doomed_bidding|talent.rotten_touch)|rune<2&!buff.runic_corruption.up
  if S.DeathCoil:IsReady() and (Player:BuffUp(S.SuddenDoomBuff) and Player:BuffUp(S.GiftoftheSanlaynBuff) and Player:BuffStack(S.EssenceoftheBloodQueenBuff) >= 3 and (S.DoomedBidding:IsAvailable() or S.RottenTouch:IsAvailable()) or Player:Rune() < 2 and Player:BuffDown(S.RunicCorruptionBuff)) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_st 4"; end
  end
  -- soul_reaper,if=target.health.pct<=35&!buff.gift_of_the_sanlayn.up&fight_remains>5
  if S.SoulReaper:IsReady() and (Target:HealthPercentage() <= 35 and Player:BuffDown(S.GiftoftheSanlaynBuff) and FightRemains > 5) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper san_st 6"; end
  end
  -- festering_strike,if=(debuff.festering_wound.stack<4&cooldown.apocalypse.remains<variable.apoc_timing)|(talent.gift_of_the_sanlayn&!buff.gift_of_the_sanlayn.up|!talent.gift_of_the_sanlayn)&(buff.festering_scythe.react|debuff.festering_wound.stack<=1-pet.abomination.active)
  if FesteringAction:IsReady() and ((FesterStacks < 4 and S.Apocalypse:CooldownRemains() < VarApocTiming) or (S.GiftoftheSanlayn:IsAvailable() and Player:BuffDown(S.GiftoftheSanlaynBuff) or not S.GiftoftheSanlayn:IsAvailable()) and (Player:BuffUp(S.FesteringScytheBuff) or FesterStacks <= 1 - num(VarAbomActive))) then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(5)) then return "festering_strike san_st 8"; end
  end
  -- wound_spender,if=(debuff.festering_wound.stack>=3-pet.abomination.active&cooldown.apocalypse.remains>variable.apoc_timing)|buff.vampiric_strike.react&cooldown.apocalypse.remains>variable.apoc_timing
  if WoundSpender:IsReady() and ((FesterStacks >= 3 - num(VarAbomActive) and S.Apocalypse:CooldownRemains() > VarApocTiming) or Player:BuffUp(S.VampiricStrikeBuff) and S.Apocalypse:CooldownRemains() > VarApocTiming) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_st 10"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&debuff.death_rot.remains<gcd|(buff.sudden_doom.react&debuff.festering_wound.stack>=1|rune<2)
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and Target:DebuffRemains(S.DeathRotDebuff) < Player:GCD() or (Player:BuffUp(S.SuddenDoomBuff) and FesterStacks >= 1 or Player:Rune() < 2)) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_st 12"; end
  end
  -- wound_spender,if=debuff.festering_wound.stack>4
  if WoundSpender:IsReady() and (FesterStacks > 4) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender san_st 14"; end
  end
  -- death_coil,if=!variable.pooling_runic_power
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil san_st 16"; end
  end
end

local function SanTrinkets()
  -- use_item,name=fyralath_the_dreamrender,if=dot.mark_of_fyralath.ticking&(active_enemies<5|active_enemies>21|fight_remains<4)&(pet.abomination.active|pet.army_ghoul.active|!talent.raise_abomination&!talent.army_of_the_dead|time>15)
  if Settings.Commons.Enabled.Items and I.Fyralath:IsReady() and (Target:DebuffUp(S.MarkofFyralathDebuff) and (ActiveEnemies < 5 or ActiveEnemies > 21 or BossFightRemains < 4) and (VarAbomActive or VarArmyGhoulActive or not S.RaiseAbomination:IsAvailable() and not S.ArmyoftheDead:IsAvailable() or HL.CombatTime() > 15)) then
    if Cast(I.Fyralath, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsItemInRange(I.Fyralath)) then return "fyralath_the_dreamrender san_trinkets 2"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- do_treacherous_transmitter_task,use_off_gcd=1,if=buff.errant_manaforge_emission.up&buff.dark_transformation.up|buff.cryptic_instructions.up&buff.dark_transformation.up|buff.realigning_nexus_convergence_divergence.up&buff.dark_transformation.up
    -- TODO: Handle the above.
    -- use_item,use_off_gcd=1,slot=trinket1,if=(variable.trinket_1_buffs|trinket.1.is.treacherous_transmitter)&(buff.dark_transformation.up&buff.dark_transformation.remains<variable.trinket_1_duration*0.73&(variable.trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown))|variable.trinket_1_duration>=fight_remains
    if Trinket1:IsReady() and ((VarTrinket1Buffs or VarTrinket1ID == I.TreacherousTransmitter:ID()) and (Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < VarTrinket1Duration * 0.73 and (VarTrinketPriority == 1 or Trinket2:CooldownDown() or not Trinket2:HasCooldown())) or VarTrinket1Duration >= BossFightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " san_trinkets 4"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=(variable.trinket_2_buffs|trinket.2.is.treacherous_transmitter)&(buff.dark_transformation.up&buff.dark_transformation.remains<variable.trinket_2_duration*0.73&(variable.trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown))|variable.trinket_2_duration>=fight_remains
    if Trinket2:IsReady() and ((VarTrinket2Buffs or VarTrinket2ID == I.TreacherousTransmitter:ID()) and (Pet:BuffUp(S.DarkTransformation) and Pet:BuffRemains(S.DarkTransformation) < VarTrinket2Duration * 0.73 and (VarTrinketPriority == 2 or Trinket1:CooldownDown() or not Trinket1:HasCooldown())) or VarTrinket2Duration >= BossFightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " san_trinkets 6"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination|!talent.summon_gargoyle&talent.army_of_the_dead&(!talent.raise_abomination&cooldown.army_of_the_dead.remains>20|talent.raise_abomination&cooldown.raise_abomination.remains>20)|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination&cooldown.dark_transformation.remains>20|talent.summon_gargoyle&cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
    if Trinket1:IsReady() and (not VarTrinket1Buffs and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown() or not Trinket2:HasCooldown() or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() or not S.SummonGargoyle:IsAvailable() and S.ArmyoftheDead:IsAvailable() and (not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > 20 or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 20) or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and S.DarkTransformation:CooldownRemains() > 20 or S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() > 20 and not VarGargActive) or BossFightRemains < 15) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " san_trinkets 8"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination|!talent.summon_gargoyle&talent.army_of_the_dead&(!talent.raise_abomination&cooldown.army_of_the_dead.remains>20|talent.raise_abomination&cooldown.raise_abomination.remains>20)|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination&cooldown.dark_transformation.remains>20|talent.summon_gargoyle&cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
    if Trinket2:IsReady() and (not VarTrinket2Buffs and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown() or not Trinket1:HasCooldown() or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() or not S.SummonGargoyle:IsAvailable() and S.ArmyoftheDead:IsAvailable() and (not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > 20 or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 20) or not SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and S.DarkTransformation:CooldownRemains() > 20 or S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() > 20 and not VarGargActive) or BossFightRemains < 15) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " san_trinkets 10"; end
    end
  end
end

local function ST()
  -- soul_reaper,if=target.health.pct<=35&fight_remains>5
  if S.SoulReaper:IsReady() and (Target:HealthPercentage() <= 35 and FightRemains > 5) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper st 2"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&variable.spend_rp|fight_remains<10
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and VarSpendRP or BossFightRemains < 10) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil st 4"; end
  end
  -- festering_strike,if=!variable.pop_wounds&debuff.festering_wound.stack<4
  if FesteringAction:IsReady() and (not VarPopWounds and FesterStacks < 4) then
    if Cast(FesteringAction, nil, nil, not Target:IsInMeleeRange(5)) then return "festering_strike st 6"; end
  end
  -- wound_spender,if=variable.pop_wounds
  if WoundSpender:IsReady() and (VarPopWounds) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender st 8"; end
  end
  -- death_coil,if=!variable.pooling_runic_power
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil st 10"; end
  end
  -- wound_spender,if=!variable.pop_wounds&debuff.festering_wound.stack>=4
  if WoundSpender:IsReady() and (not VarPopWounds and FesterStacks >= 4) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender st 12"; end
  end
end

local function Trinkets()
  -- use_item,name=fyralath_the_dreamrender,if=dot.mark_of_fyralath.ticking&(active_enemies<5|active_enemies>21|fight_remains<4)&(pet.abomination.active|pet.army_ghoul.active|!talent.raise_abomination&!talent.army_of_the_dead|time>15)
  if Settings.Commons.Enabled.Items and I.Fyralath:IsReady() and (Target:DebuffUp(S.MarkofFyralathDebuff) and (ActiveEnemies < 5 or ActiveEnemies > 21 or BossFightRemains < 4) and (VarAbomActive or VarArmyGhoulActive or not S.RaiseAbomination:IsAvailable() and not S.ArmyoftheDead:IsAvailable() or HL.CombatTime() > 15)) then
    if Cast(I.Fyralath, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(25)) then return "fyralath_the_dreamrender trinkets 2"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- do_treacherous_transmitter_task,use_off_gcd=1,if=buff.errant_manaforge_emission.up&buff.dark_transformation.up|buff.cryptic_instructions.up&buff.dark_transformation.up|buff.realigning_nexus_convergence_divergence.up&buff.dark_transformation.up
    -- TODO: Handle the above.
    -- use_item,use_off_gcd=1,slot=trinket1,if=(variable.trinket_1_buffs|trinket.1.is.treacherous_transmitter)&((!talent.summon_gargoyle&((!talent.army_of_the_dead|talent.army_of_the_dead&cooldown.army_of_the_dead.remains>trinket.1.cooldown.duration*0.51|death_knight.disable_aotd|talent.raise_abomination&cooldown.raise_abomination.remains>trinket.1.cooldown.duration*0.51)&((20>variable.trinket_1_duration&pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=variable.trinket_1_duration*1.2|20<=variable.trinket_1_duration&cooldown.apocalypse.remains<gcd&buff.dark_transformation.up)|(!talent.apocalypse|active_enemies>=2)&buff.dark_transformation.up)|pet.army_ghoul.active&pet.army_ghoul.remains<variable.trinket_1_duration*1.2|pet.abomination.active&pet.abomination.remains<variable.trinket_1_duration*1.2)|talent.summon_gargoyle&pet.gargoyle.active&pet.gargoyle.remains<variable.trinket_1_duration*1.2|cooldown.summon_gargoyle.remains>80)&(variable.trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown))|variable.trinket_1_duration>=fight_remains
    if Trinket1:IsReady() and ((VarTrinket1Buffs or VarTrinket1ID == I.TreacherousTransmitter:ID()) and ((not S.SummonGargoyle:IsAvailable() and ((not S.ArmyoftheDead:IsAvailable() or S.ArmyoftheDead:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > VarTrinket1CD * 0.51 or Settings.Commons.DisableAotD or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > VarTrinket1CD * 0.51) and ((20 > VarTrinket1Duration and VarApocGhoulActive and VarApocGhoulRemains <= VarTrinket1Duration * 1.2 or 20 <= VarTrinket1Duration and S.Apocalypse:CooldownRemains() < Player:GCD() and Pet:BuffUp(S.DarkTransformation)) or (not S.Apocalypse:IsAvailable() or ActiveEnemies >= 2) and Pet:BuffUp(S.DarkTransformation)) or VarArmyGhoulActive and VarArmyGhoulRemains < VarTrinket1Duration * 1.2 or VarAbomActive and VarAbomRemains < VarTrinket1Duration * 1.2) or S.SummonGargoyle:IsAvailable() and VarGargActive and VarGargRemains < VarTrinket1Duration * 1.2 or S.SummonGargoyle:CooldownRemains() > 80) and (VarTrinketPriority == 1 or Trinekt2:CooldownDown() or not Trinket2:HasCooldown())) or VarTrinket1Duration >= BossFightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 4"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=(variable.trinket_2_buffs|trinket.2.is.treacherous_transmitter)&((!talent.summon_gargoyle&((!talent.army_of_the_dead|talent.army_of_the_dead&cooldown.army_of_the_dead.remains>trinket.2.cooldown.duration*0.51|death_knight.disable_aotd|talent.raise_abomination&cooldown.raise_abomination.remains>trinket.2.cooldown.duration*0.51)&((20>variable.trinket_2_duration&pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=variable.trinket_2_duration*1.2|20<=variable.trinket_2_duration&cooldown.apocalypse.remains<gcd&buff.dark_transformation.up)|(!talent.apocalypse|active_enemies>=2)&buff.dark_transformation.up)|pet.army_ghoul.active&pet.army_ghoul.remains<variable.trinket_2_duration*1.2|pet.abomination.active&pet.abomination.remains<variable.trinket_2_duration*1.2)|talent.summon_gargoyle&pet.gargoyle.active&pet.gargoyle.remains<variable.trinket_2_duration*1.2|cooldown.summon_gargoyle.remains>80)&(variable.trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown))|variable.trinket_2_duration>=fight_remains
    if Trinket2:IsReady() and ((VarTrinket2Buffs or VarTrinket2ID == I.TreacherousTransmitter:ID()) and ((not S.SummonGargoyle:IsAvailable() and ((not S.ArmyoftheDead:IsAvailable() or S.ArmyoftheDead:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > VarTrinket2CD * 0.51 or Settings.Commons.DisableAotD or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > VarTrinket2CD * 0.51) and ((20 > VarTrinket2Duration and VarApocGhoulActive and VarApocGhoulRemains <= VarTrinket2Duration * 1.2 or 20 <= VarTrinket2Duration and S.Apocalypse:CooldownRemains() < Player:GCD() and Pet:BuffUp(S.DarkTransformation)) or (not S.Apocalypse:IsAvailable() or ActiveEnemies >= 2) and Pet:BuffUp(S.DarkTransformation)) or VarArmyGhoulActive and VarArmyGhoulRemains < VarTrinket2Duration * 1.2 or VarAbomActive and VarAbomRemains < VarTrinket2Duration * 1.2) or S.SummonGargoyle:IsAvailable() and VarGargActive and VarGargRemains < VarTrinket2Duration * 1.2 or S.SummonGargoyle:CooldownRemains() > 80) and (VarTrinketPriority == 2 or Trinket1:CooldownDown() or not Trinket1:HasCooldown())) or VarTrinket2Duration >= BossFightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " san_trinkets 6"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination|!talent.summon_gargoyle&talent.army_of_the_dead&(!talent.raise_abomination&cooldown.army_of_the_dead.remains>20|talent.raise_abomination&cooldown.raise_abomination.remains>20)|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination&cooldown.dark_transformation.remains>20|talent.summon_gargoyle&cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
    if Trinket1:IsReady() and (not VarTrinket1Buffs and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown() or not Trinket2:HasCooldown() or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() or not S.SummonGargoyle:IsAvailable() and S.ArmyoftheDead:IsAvailable() and (not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > 20 or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 20) or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and S.DarkTransformation:CooldownRemains() > 20 or S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() > 20 and not VarGargActive) or BossFightRemains < 15) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 8"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination|!talent.summon_gargoyle&talent.army_of_the_dead&(!talent.raise_abomination&cooldown.army_of_the_dead.remains>20|talent.raise_abomination&cooldown.raise_abomination.remains>20)|!talent.summon_gargoyle&!talent.army_of_the_dead&!talent.raise_abomination&cooldown.dark_transformation.remains>20|talent.summon_gargoyle&cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
    if Trinket2:IsReady() and (not VarTrinket2Buffs and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown() or not Trinket1:HasCooldown() or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() or not S.SummonGargoyle:IsAvailable() and S.ArmyoftheDead:IsAvailable() and (not S.RaiseAbomination:IsAvailable() and S.ArmyoftheDead:CooldownRemains() > 20 or S.RaiseAbomination:IsAvailable() and S.RaiseAbomination:CooldownRemains() > 20) or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDead:IsAvailable() and not S.RaiseAbomination:IsAvailable() and S.DarkTransformation:CooldownRemains() > 20 or S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() > 20 and not VarGargActive) or BossFightRemains < 15) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " san_trinkets 10"; end
    end
  end
end

local function Variables()
  -- variable,name=st_planning,op=setif,value=1,value_else=0,condition=active_enemies=1&(!raid_event.adds.exists|raid_event.adds.in>15)
  VarSTPlanning = ActiveEnemies == 1
  -- variable,name=adds_remain,op=setif,value=1,value_else=0,condition=active_enemies>=2&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>6)
  VarAddsRemain = ActiveEnemies >= 2
  -- variable,name=apoc_timing,op=setif,value=7,value_else=3,condition=cooldown.apocalypse.remains<10&debuff.festering_wound.stack<=4&cooldown.unholy_assault.remains>10
  VarApocTiming = (S.Apocalypse:CooldownRemains() < 10 and FesterStacks <= 4 and S.UnholyAssault:CooldownRemains() > 10) and 7 or 3
  -- variable,name=pop_wounds,op=setif,value=1,value_else=0,condition=(cooldown.apocalypse.remains>variable.apoc_timing|!talent.apocalypse)&(debuff.festering_wound.stack>=1&cooldown.unholy_assault.remains<20&talent.unholy_assault&variable.st_planning|debuff.rotten_touch.up&debuff.festering_wound.stack>=1|debuff.festering_wound.stack>=4-pet.abomination.active)|fight_remains<5&debuff.festering_wound.stack>=1
  VarPopWounds = (S.Apocalypse:CooldownRemains() > VarApocTiming or not S.Apocalypse:IsAvailable()) and (FesterStacks >= 1 and S.UnholyAssault:CooldownRemains() < 20 and S.UnholyAssault:IsAvailable() and VarSTPlanning or Target:DebuffUp(S.RottenTouchDebuff) and FesterStacks >= 1 or FesterStacks >= 4 - num(VarAbomActive)) or BossFightRemains < 5 and FesterStacks >= 1
  -- variable,name=pooling_runic_power,op=setif,value=1,value_else=0,condition=talent.vile_contagion&cooldown.vile_contagion.remains<3&runic_power<60&!variable.st_planning
  VarPoolingRunicPower = S.VileContagion:IsAvailable() and S.VileContagion:CooldownRemains() < 3 and Player:RunicPower() < 60 and not VarSTPlanning
  -- variable,name=spend_rp,op=setif,value=1,value_else=0,condition=(!talent.rotten_touch|talent.rotten_touch&!debuff.rotten_touch.up|runic_power.deficit<20)&((talent.improved_death_coil&(active_enemies=2|talent.coil_of_devastation)|rune<3|pet.gargoyle.active|buff.sudden_doom.react|!variable.pop_wounds&debuff.festering_wound.stack>=4))
  VarSpendRP = (not S.RottenTouch:IsAvailable() or S.RottenTouch:IsAvailable() and Target:DebuffDown(S.RottenTouchDebuff) or Player:RunicPowerDeficit() < 20) and (S.ImprovedDeathCoil:IsAvailable() and (ActiveEnemies == 2 or S.CoilofDevastation:IsAvailable()) or Player:Rune() < 3 or VarGargActive or Player:BuffUp(S.SuddenDoomBuff) or not VarPopWounds and FesterStacks >= 4)
end

--- ===== APL Main =====
local function APL()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(5)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
    Enemies10ySplashCount = Target:GetEnemiesInSplashRangeCount(10)
  else
    EnemiesMeleeCount = 1
    Enemies10ySplashCount = 1
  end
  ActiveEnemies = mathmax(EnemiesMeleeCount, Enemies10ySplashCount)

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemiesMelee, false)
    end

    -- Check which enemies don't have Virulent Plague
    EnemiesWithoutVP = UnitsWithoutVP(Enemies10ySplash)

    -- Is Abomination active?
    VarAbomActive = Ghoul:AbomActive()
    VarAbomRemains = Ghoul:AbomRemains()
    -- Is Apocalypse Ghoul active?
    VarApocGhoulActive = S.Apocalypse:TimeSinceLastCast() <= 15
    VarApocGhoulRemains = (VarApocGhoulActive) and 15 - S.Apocalypse:TimeSinceLastCast() or 0
    -- Is Army active?
    VarArmyGhoulActive = S.ArmyoftheDead:TimeSinceLastCast() <= 30
    VarArmyGhoulRemains = (VarArmyGhoulActive) and 30 - S.ArmyoftheDead:TimeSinceLastCast() or 0
    -- Is Gargoyle active?
    VarGargActive = Ghoul:GargActive()
    VarGargRemains = Ghoul:GargRemains()

    -- Check our stacks of Festering Wounds
    FesterStacks = Target:DebuffStack(S.FesteringWoundDebuff)

    -- Use the right version of Festering Strike/Scythe
    FesteringAction = (S.FesteringScytheAction:IsLearned()) and S.FesteringScytheAction or S.FesteringStrike
    -- Use the right WoundSpender
    WoundSpender = (S.VampiricStrikeAction:IsLearned()) and S.VampiricStrikeAction or ((S.ClawingShadows:IsAvailable()) and S.ClawingShadows or S.ScourgeStrike)
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady() and DeathStrikeHeal() then
      if Cast(S.DeathStrike) then return "death_strike low hp or proc"; end
    end
    -- auto_attack
    -- Interrupts (here instead of HighPrioActions)
    local ShouldReturn = Everyone.Interrupt(S.MindFreeze, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Things to do if more than 10y away from our target (10y instead of melee range to avoid the rotation getting twitchy when near max melee range).
    if not Target:IsInRange(10) then
      -- Manually added: Outbreak if targets are missing VP and out of range
      if S.Outbreak:IsReady() and (EnemiesWithoutVP > 0) then
        if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak out_of_range"; end
      end
      -- Manually added: epidemic,if=!variable.pooling_runic_power&active_enemies=0
      if S.Epidemic:IsReady() and AoEON() and S.VirulentPlagueDebuff:AuraActiveCount() > 1 and not VarPoolingRunicPower then
        if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic out_of_range"; end
      end
      -- Manually added: death_coil,if=!variable.pooling_runic_power&active_enemies=0
      if S.DeathCoil:IsReady() and S.VirulentPlagueDebuff:AuraActiveCount() < 2 and not VarPoolingRunicPower then
        if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil out_of_range"; end
      end
    end
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=san_trinkets,if=talent.vampiric_strike
    if S.VampiricStrike:IsAvailable() then
      local ShouldReturn = SanTrinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinkets,if=!talent.vampiric_strike
    if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and not S.VampiricStrike:IsAvailable() then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials
    if (CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds_shared
    if CDsON() then
      local ShouldReturn = CDsShared(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds,if=!talent.vampiric_strike
    if CDsON() and not S.VampiricStrike:IsAvailable() then
      local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cds_san,if=talent.vampiric_strike
    if CDsON() and S.VampiricStrike:IsAvailable() then
      local ShouldReturn = CDsSan(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies<4&active_enemies>=2
    if AoEON() and ActiveEnemies < 4 and ActiveEnemies >= 2 then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_burst,if=active_enemies>=4&buff.death_and_decay.up
    if AoEON() and ActiveEnemies >= 4 and Player:BuffUp(S.DeathAndDecayBuff) then
      local ShouldReturn = AoEBurst(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=4&!buff.death_and_decay.up
    if AoEON() and ActiveEnemies >= 4 and Player:BuffDown(S.DeathAndDecayBuff) then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=san_fishing,if=talent.gift_of_the_sanlayn&!buff.gift_of_the_sanlayn.up&buff.essence_of_the_blood_queen.remains<cooldown.dark_transformation.remains+2
    if S.GiftoftheSanlayn:IsAvailable() and Player:BuffDown(S.GiftoftheSanlaynBuff) and Player:BuffRemains(S.EssenceoftheBloodQueenBuff) < S.DarkTransformation:CooldownRemains() + 2 then
      local ShouldReturn = SanFishing(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=san_st,if=active_enemies=1&talent.vampiric_strike
    if (ActiveEnemies == 1 or not AoEON()) and S.VampiricStrike:IsAvailable() then
      local ShouldReturn = SanST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies=1&!talent.vampiric_strike
    if (ActiveEnemies == 1 or not AoEON()) and not S.VampiricStrike:IsAvailable() then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- Add pool resources icon if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool_resources"; end
  end
end

local function Init()
  S.VirulentPlagueDebuff:RegisterAuraTracking()
  S.FesteringWoundDebuff:RegisterAuraTracking()

  HR.Print("Unholy DK rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(252, APL, Init)
