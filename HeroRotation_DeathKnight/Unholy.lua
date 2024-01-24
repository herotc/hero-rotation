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
  I.AlgetharPuzzleBox:ID(),
  I.Fyralath:ID(),
  I.IrideusFragment:ID(),
  I.VialofAnimatedBlood:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Rotation Var
local ShouldReturn -- Used to get the return string
local no_heal

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Commons2 = HR.GUISettings.APL.DeathKnight.Commons2,
  Unholy = HR.GUISettings.APL.DeathKnight.Unholy
}

-- Variables
local VarGargSetupComplete
local VarApocTiming
local VarFesterTracker
local VarPopWounds
local VarPoolingRunicPower
local VarSTPlanning
local VarAddsRemain
local VarApocGhoulActive, VarApocGhoulRemains
local VarArmyGhoulActive, VarArmyGhoulRemains
local VarGargActive, VarGargRemains
local WoundSpender = (S.ClawingShadows:IsAvailable()) and S.ClawingShadows or S.ScourgeStrike
local AnyDnD = (S.Defile:IsAvailable()) and S.Defile or S.DeathAndDecay
local FesterStacks
local BossFightRemains = 11111
local FightRemains = 11111
local Ghoul = HL.GhoulTable

-- Enemies Variables
local EnemiesMelee, EnemiesMeleeCount, ActiveEnemies
local Enemies10ySplash, Enemies10ySplashCount
local EnemiesWithoutVP

-- Stun Interrupts List
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

-- Event Registrations
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
  WoundSpender = (S.ClawingShadows:IsAvailable()) and S.ClawingShadows or S.ScourgeStrike
  AnyDnD = (S.Defile:IsAvailable()) and S.Defile or S.DeathAndDecay
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

-- Helper Functions
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

-- CastTargetIf Filter Functions
local function EvaluateTargetIfFilterFWStack(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff))
end

local function EvaluateTargetIfFilterSoulReaper(TargetUnit)
  -- target_if=min:dot.soul_reaper.remains
  return (TargetUnit:DebuffRemains(S.SoulReaper))
end

-- CastTargetIf Condition Functions
local function EvaluateTargetIfApocalypseAoECDs(TargetUnit)
  -- if=talent.bursting_sores&debuff.festering_wound.up&(!death_and_decay.ticking&cooldown.death_and_decay.remains&rune<3|death_and_decay.ticking&rune=0)
  return (S.BurstingSores:IsAvailable() and TargetUnit:DebuffUp(S.FesteringWoundDebuff) and (Player:BuffDown(S.DeathAndDecayBuff) and S.DeathAndDecay:CooldownDown() and Player:Rune() < 3 or Player:BuffUp(S.DeathAndDecayBuff) and Player:Rune() == 0))
end

local function EvaluateTargetIfApocalypseAoECDs2(TargetUnit)
  -- if=!talent.bursting_sores&debuff.festering_wound.stack>=4|set_bonus.tier31_2pc&debuff.festering_wound.stack>=1
  return (not S.BurstingSores:IsAvailable() and TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4 or Player:HasTier(31, 2) and TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 1)
end

local function EvaluateTargetIfApocalypseCDs(TargetUnit)
  -- if=variable.st_planning&debuff.festering_wound.stack>=4
  -- Note: st_planning handled outside of the CastTargetIf
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4)
end

local function EvaluateTargetIfFesteringStrikeAoESetup(TargetUnit)
  -- if=cooldown.apocalypse.remains<variable.apoc_timing&debuff.festering_wound.stack<4
  -- Note: Apocalypse CD check handled before CastTargetIf
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 4)
end

local function EvaluateTargetIfFesteringStrikeST(TargetUnit)
  -- if=!variable.pop_wounds&debuff.festering_wound.stack<4
  -- Note: !variable.pop_wounds check handled before CastTargetIf
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 4)
end

local function EvaluateTargetIfFesteringStrikeST2(TargetUnit)
  -- if=!variable.pop_wounds&debuff.festering_wound.stack>=4
  -- Note: !variable.pop_wounds check handled before CastTargetIf
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4)
end

local function EvaluateTargetIfSoulReaperCDs(TargetUnit)
  -- if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  return ((TargetUnit:TimeToX(35) < 5 or TargetUnit:HealthPercentage() <= 35) and TargetUnit:TimeToDie() > (TargetUnit:DebuffRemains(S.SoulReaper) + 5))
end

local function EvaluateTargetIfUnholyAssaultAoECDs(TargetUnit)
  -- if=debuff.festering_wound.stack<=2|buff.dark_transformation.up
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 2 or Pet:BuffUp(S.DarkTransformation))
end

local function EvaluateTargetIfVileContagionAoECDs(TargetUnit)
  -- if=debuff.festering_wound.stack>=4&cooldown.any_dnd.remains<3
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4 and AnyDnD:CooldownRemains() < 3)
end

local function EvaluateTargetIfWoundSpenderAoEBurst(TargetUnit)
  -- if=debuff.festering_wound.stack>=1
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 1)
end

-- CastCycle Condition Functions
local function EvaluateCycleOutbreak(TargetUnit)
  -- target_if=target.time_to_die>dot.virulent_plague.remains&(dot.virulent_plague.refreshable|talent.superstrain&(dot.frost_fever_superstrain.refreshable|dot.blood_plague_superstrain.refreshable))&(!talent.unholy_blight|talent.unholy_blight&cooldown.unholy_blight.remains>15%((talent.superstrain*3)+(talent.plaguebringer*2)+(talent.ebon_fever*2)))
  return (TargetUnit:TimeToDie() > TargetUnit:DebuffRemains(S.VirulentPlagueDebuff) and (TargetUnit:DebuffRefreshable(S.VirulentPlagueDebuff) or S.Superstrain:IsAvailable() and (TargetUnit:DebuffRefreshable(S.FrostFeverDebuff) or TargetUnit:DebuffRefreshable(S.BloodPlagueDebuff))) and (not S.UnholyBlight:IsAvailable() or S.UnholyBlight:IsAvailable() and S.UnholyBlight:CooldownRemains() > 15 / ((num(S.Superstrain:IsAvailable()) * 3) + (num(S.Plaguebringer:IsAvailable()) * 2) + (num(S.EbonFever:IsAvailable()) * 2))))
end

-- APL Functions
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
      if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead precombat 2 displaystyle"; end
    end
  end
  -- army_of_the_dead,precombat_time=2,if=!equipped.fyralath_the_dreamrender|raid_event.adds.exists
  if S.ArmyoftheDead:IsReady() and (not I.Fyralath:IsEquipped()) then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyOfTheDead) then return "army_of_the_dead precombat 4"; end
  end
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit)&!variable.trinket_1_exclude
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit)&!variable.trinket_2_exclude
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%45=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%45=0)
  -- variable,name=trinket_1_manual,value=trinket.1.is.algethar_puzzle_box|trinket.1.is.irideus_fragment|trinket.1.is.vial_of_animated_blood
  -- variable,name=trinket_2_manual,value=trinket.2.is.algethar_puzzle_box|trinket.2.is.irideus_fragment|trinket.2.is.vial_of_animated_blood
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs&(trinket.2.has_cooldown&!variable.trinket_2_exclude|!trinket.1.has_cooldown)|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync)*(1+((trinket.1.ilvl-trinket.2.ilvl)%100)))
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  -- TODO: Trinket sync/priority stuff. Currently unable to pull trinket CD durations because WoW's API is bad.
  -- Manually added: outbreak
  if S.Outbreak:IsReady() then
    if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak precombat 6"; end
  end
  -- Manually added: festering_strike if in melee range
  if S.FesteringStrike:IsReady() then
    if Cast(S.FesteringStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "festering_strike precombat 8"; end
  end
end

local function AoE()
  -- epidemic,if=!variable.pooling_runic_power|fight_remains<10
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower or FightRemains < 10) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe 2"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=variable.pop_wounds
  if WoundSpender:IsReady() and (VarPopWounds) then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender aoe 4"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=!variable.pop_wounds
  if S.FesteringStrike:IsReady() and (not VarPopWounds) then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5)) then return "festering_strike aoe 6"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&!talent.epidemic
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and not S.Epidemic:IsAvailable()) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil aoe 8"; end
  end
end

local function AoEBurst()
  -- epidemic,if=(rune<1|talent.bursting_sores&death_knight.fwounded_targets=0|!talent.bursting_sores)&!variable.pooling_runic_power&(active_enemies>=6|runic_power.deficit<30|buff.festermight.stack=20)
  if S.Epidemic:IsReady() and ((Player:Rune() < 1 or S.BurstingSores:IsAvailable() and S.FesteringWoundDebuff:AuraActiveCount() == 0 or not S.BurstingSores:IsAvailable()) and not VarPoolingRunicPower and (ActiveEnemies >= 6 or Player:RunicPowerDeficit() < 30 or Player:BuffStack(S.FestermightBuff) == 20)) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_burst 2"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=1
  if WoundSpender:IsReady() then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfWoundSpenderAoEBurst, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender aoe_burst 4"; end
  end
  -- epidemic,if=!variable.pooling_runic_power|fight_remains<10
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower or FightRemains < 10) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_burst 6"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&!talent.epidemic
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and not S.Epidemic:IsAvailable()) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil aoe_burst 8"; end
  end
  -- wound_spender
  if WoundSpender:IsReady() then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender aoe_burst 10"; end
  end
end

local function AoECDs()
  -- vile_contagion,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=4&cooldown.any_dnd.remains<3
  if S.VileContagion:IsReady() and (AnyDnD:CooldownRemains() < 3) then
    if Everyone.CastTargetIf(S.VileContagion, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfVileContagionAoECDs, not Target:IsSpellInRange(S.VileContagion)) then return "vile_contagion aoe_cooldowns 2"; end
  end
  -- summon_gargoyle
  if S.SummonGargoyle:IsReady() then
    if Cast(S.SummonGargoyle, Settings.Unholy.GCDasOffGCD.SummonGargoyle) then return "summon_gargoyle aoe_cooldowns 4"; end
  end
  -- abomination_limb,if=rune<2|buff.festermight.stack>10|!talent.festermight|buff.festermight.up&buff.festermight.remains<12
  if S.AbominationLimb:IsCastable() and (Player:Rune() < 2 or FesterStacks > 10 or not S.Festermight:IsAvailable() or Player:BuffUp(S.FestermightBuff) and Player:BuffRemains(S.FestermightBuff) < 12) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(20)) then return "abomination_limb aoe_cooldowns 6"; end
  end
  -- apocalypse,target_if=min:debuff.festering_wound.stack,if=talent.bursting_sores&debuff.festering_wound.up&(!death_and_decay.ticking&cooldown.death_and_decay.remains&rune<3|death_and_decay.ticking&rune=0)
  if S.Apocalypse:IsReady() then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfApocalypseAoECDs, not Target:IsInMeleeRange(5)) then return "apocalypse aoe_cooldowns 8"; end
  end
  -- apocalypse,target_if=max:debuff.festering_wound.stack,if=!talent.bursting_sores&debuff.festering_wound.stack>=4|set_bonus.tier31_2pc&debuff.festering_wound.stack>=1
  if S.Apocalypse:IsReady() then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfApocalypseAoECDs2, not Target:IsInMeleeRange(5)) then return "apocalypse aoe_cooldowns 9"; end
  end
  -- unholy_assault,target_if=min:debuff.festering_wound.stack,if=debuff.festering_wound.stack<=2|buff.dark_transformation.up
  if S.UnholyAssault:IsCastable() then
    if Everyone.CastTargetIf(S.UnholyAssault, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfUnholyAssaultAoECDs, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.UnholyAssault) then return "unholy_assault aoe_cooldowns 10"; end
  end
  -- raise_dead,if=!pet.ghoul.active
  if S.RaiseDead:IsCastable() then
    if Settings.Unholy.RaiseDeadCastLeft then
      if HR.CastLeft(S.RaiseDead) then return "raise_dead aoe_cooldowns 12 left"; end
    else
      if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead aoe_cooldowns 12 displaystyle"; end
    end
  end
  -- dark_transformation,if=(cooldown.any_dnd.remains<10&talent.infected_claws&((cooldown.vile_contagion.remains|raid_event.adds.exists&raid_event.adds.in>10)&death_knight.fwounded_targets<active_enemies|!talent.vile_contagion)&(raid_event.adds.remains>5|!raid_event.adds.exists)|!talent.infected_claws)
  if S.DarkTransformation:IsReady() and (AnyDnD:CooldownRemains() < 10 and S.InfectedClaws:IsAvailable() and (S.FesteringWoundDebuff:AuraActiveCount() < ActiveEnemies or not S.VileContagion:IsAvailable()) or not S.InfectedClaws:IsAvailable()) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation aoe_cooldowns 14"; end
  end
  -- empower_rune_weapon,if=buff.dark_transformation.up
  if S.EmpowerRuneWeapon:IsCastable() and (Pet:BuffUp(S.DarkTransformation)) then
    if Cast(S.EmpowerRuneWeapon, Settings.Commons2.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon aoe_cooldowns 16"; end
  end
  -- sacrificial_pact,if=!buff.dark_transformation.up&cooldown.dark_transformation.remains>6|fight_remains<gcd
  if S.SacrificialPact:IsReady() and (Pet:BuffDown(S.DarkTransformation) and S.DarkTransformation:CooldownRemains() > 6 or FightRemains < Player:GCD()) then
    if Cast(S.SacrificialPact, Settings.Commons2.GCDasOffGCD.SacrificialPact) then return "sacrificial_pact aoe_cooldowns 18"; end
  end
end

local function AoESetup()
  -- any_dnd,if=(!talent.bursting_sores|death_knight.fwounded_targets=active_enemies|death_knight.fwounded_targets>=8|raid_event.adds.exists&raid_event.adds.remains<=11&raid_event.adds.remains>5)
  if AnyDnD:IsReady() and (not S.BurstingSores:IsAvailable() or S.FesteringWoundDebuff:AuraActiveCount() == ActiveEnemies or S.FesteringWoundDebuff:AuraActiveCount() >= 8) then
    if Cast(AnyDnD, Settings.Commons2.GCDasOffGCD.DeathAndDecay) then return "any_dnd aoe_setup 2"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=death_knight.fwounded_targets<active_enemies&talent.bursting_sores
  if S.FesteringStrike:IsReady() and (S.FesteringWoundDebuff:AuraActiveCount() < ActiveEnemies and S.BurstingSores:IsAvailable()) then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5)) then return "festering_strike aoe_setup 4"; end
  end
  -- epidemic,if=!variable.pooling_runic_power|fight_remains<10
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower or FightRemains < 10) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic aoe_setup 6"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=death_knight.fwounded_targets<active_enemies
  if S.FesteringStrike:IsReady() and (S.FesteringWoundDebuff:AuraActiveCount() < ActiveEnemies) then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5)) then return "festering_strike aoe_setup 8"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=cooldown.apocalypse.remains<variable.apoc_timing&debuff.festering_wound.stack<4
  if S.FesteringStrike:IsReady() and (S.Apocalypse:CooldownRemains() < VarApocTiming) then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeAoESetup, not Target:IsInMeleeRange(5)) then return "festering_strike aoe_setup 10"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&!talent.epidemic
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and not S.Epidemic:IsAvailable()) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil aoe_setup 12"; end
  end
end

local function Cooldowns()
  -- summon_gargoyle,if=buff.commander_of_the_dead.up|!talent.commander_of_the_dead
  if S.SummonGargoyle:IsCastable() and (Player:BuffUp(S.CommanderoftheDeadBuff) or not S.CommanderoftheDead:IsAvailable()) then
    if Cast(S.SummonGargoyle, Settings.Unholy.GCDasOffGCD.SummonGargoyle) then return "summon_gargoyle cooldowns 2"; end
  end
  -- raise_dead,if=!pet.ghoul.active
  if S.RaiseDead:IsCastable() then
    if Settings.Unholy.RaiseDeadCastLeft then
      if HR.CastLeft(S.RaiseDead) then return "raise_dead cooldowns 4 left"; end
    else
      if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead cooldowns 4 displaystyle"; end
    end
  end
  -- dark_transformation,if=cooldown.apocalypse.remains<5
  if S.DarkTransformation:IsReady() and (S.Apocalypse:CooldownRemains() < 5) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cooldowns 6"; end
  end
  -- apocalypse,target_if=max:debuff.festering_wound.stack,if=variable.st_planning&debuff.festering_wound.stack>=4
  if S.Apocalypse:IsReady() and (VarSTPlanning) then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfApocalypseCDs, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.Apocalypse) then return "apocalypse cooldowns 8"; end
  end
  -- empower_rune_weapon,if=variable.st_planning&(pet.gargoyle.active&pet.gargoyle.remains<=23|!talent.summon_gargoyle&talent.army_of_the_damned&pet.army_ghoul.active&pet.apoc_ghoul.active|!talent.summon_gargoyle&!talent.army_of_the_damned&buff.dark_transformation.up|!talent.summon_gargoyle&!talent.summon_gargoyle&buff.dark_transformation.up)|fight_remains<=21
  if S.EmpowerRuneWeapon:IsCastable() and (VarSTPlanning and (VarGargActive and VarGargRemains <= 23 or not S.SummonGargoyle:IsAvailable() and S.ArmyoftheDamned:IsAvailable() and VarArmyGhoulActive and VarApocGhoulActive or not S.SummonGargoyle:IsAvailable() and not S.ArmyoftheDamned:IsAvailable() and Pet:BuffUp(S.DarkTransformation) or not S.SummonGargoyle:IsAvailable() and Pet:BuffUp(S.DarkTransformation)) or FightRemains <= 21) then
    if Cast(S.EmpowerRuneWeapon, Settings.Commons2.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 10"; end
  end
  -- abomination_limb,if=rune<3&variable.st_planning
  if S.AbominationLimb:IsCastable() and (Player:Rune() < 3 and VarSTPlanning) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Signature) then return "abomination_limb cooldowns 12"; end
  end
  -- unholy_assault,target_if=min:debuff.festering_wound.stack,if=variable.st_planning
  if S.UnholyAssault:IsReady() and (VarSTPlanning) then
    if Everyone.CastTargetIf(S.UnholyAssault, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.UnholyAssault) then return "unholy_assault cooldowns 14"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>5
  if S.SoulReaper:IsReady() and (ActiveEnemies == 1 and (Target:TimeToX(35) < 5 or Target:HealthPercentage() <= 35) and Target:TimeToDie() > 5) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsSpellInRange(S.SoulReaper)) then return "soul_reaper cooldowns 16"; end
  end
  -- soul_reaper,target_if=min:dot.soul_reaper.remains,if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (ActiveEnemies >= 2) then
    if Everyone.CastTargetIf(S.SoulReaper, EnemiesMelee, "min", EvaluateTargetIfFilterSoulReaper, EvaluateTargetIfSoulReaperCDs, not Target:IsSpellInRange(S.SoulReaper)) then return "soul_reaper cooldowns 18"; end
  end
end

local function GargSetup()
  -- apocalypse,if=debuff.festering_wound.stack>=4&(buff.commander_of_the_dead.up&pet.gargoyle.remains<23|!talent.commander_of_the_dead)
  if S.Apocalypse:IsReady() and (FesterStacks >= 4 and (Player:BuffUp(S.CommanderoftheDeadBuff) and VarGargRemains < 23 or not S.CommanderoftheDead:IsAvailable())) then
    if Cast(S.Apocalypse, Settings.Unholy.GCDasOffGCD.Apocalypse, nil, not Target:IsInMeleeRange(5)) then return "apocalypse garg_setup 2"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>5
  if S.SoulReaper:IsReady() and (ActiveEnemies == 1 and (Target:TimeToX(35) < 5 or Target:HealthPercentage() <= 35) and Target:TimeToDie() > 5) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper garg_setup 4"; end
  end
  -- any_dnd,if=!death_and_decay.ticking&debuff.festering_wound.stack>1
  if AnyDnD:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and FesterStacks > 1) then
    if Cast(AnyDnD, Settings.Commons2.GCDasOffGCD.DeathAndDecay) then return "any_dnd garg_setup 6"; end
  end
  -- summon_gargoyle,use_off_gcd=1,if=buff.commander_of_the_dead.up|!talent.commander_of_the_dead&runic_power>=40
  if S.SummonGargoyle:IsCastable() and CDsON() and (Player:BuffUp(S.CommanderoftheDeadBuff) or not S.CommanderoftheDead:IsAvailable() and Player:RunicPower() >= 40) then
    if Cast(S.SummonGargoyle, Settings.Unholy.GCDasOffGCD.SummonGargoyle) then return "summon_gargoyle garg_setup 8"; end
  end
  if CDsON() and (VarGargActive and VarGargRemains <= 23) then
    -- empower_rune_weapon,if=pet.gargoyle.active&pet.gargoyle.remains<=23
    if S.EmpowerRuneWeapon:IsCastable() then
      if Cast(S.EmpowerRuneWeapon, Settings.Commons2.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon garg_setup 10"; end
    end
    -- unholy_assault,if=pet.gargoyle.active&pet.gargoyle.remains<=23
    if S.UnholyAssault:IsCastable() then
      if Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault, nil, not Target:IsInMeleeRange(5)) then return "unholy_assault garg_setup 12"; end
    end
  end
  -- dark_transformation,if=talent.commander_of_the_dead&runic_power>40|!talent.commander_of_the_dead
  if S.DarkTransformation:IsReady() and (S.CommanderoftheDead:IsAvailable() and Player:RunicPower() > 40 or not S.CommanderoftheDead:IsAvailable()) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation garg_setup 14"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack=0|!talent.apocalypse|runic_power<40&!pet.gargoyle.active
  if S.FesteringStrike:IsReady() and (FesterStacks == 0 or not S.Apocalypse:IsAvailable() or Player:RunicPower() < 40 and not VarGargActive) then
    if Cast(S.FesteringStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "festering_strike garg_setup 16"; end
  end
  -- death_coil,if=rune<=1
  if S.DeathCoil:IsReady() and (Player:Rune() <= 1) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil garg_setup 18"; end
  end
end

local function HighPrioActions()
  -- mind_freeze,if=target.debuff.casting.react
  -- Note: Kept interrupts in APL()
  if Settings.Commons.UseAMSAMZOffensively then
    -- antimagic_shell,if=runic_power.deficit>40&(pet.gargoyle.active|!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>cooldown.antimagic_shell.duration)
    if S.AntiMagicShell:IsCastable() and (Player:RunicPowerDeficit() > 40 and (VarGargActive or not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 40)) then
      if Cast(S.AntiMagicShell, Settings.Commons2.GCDasOffGCD.AntiMagicShell) then return "antimagic_shell ams_amz 2"; end
    end
    -- antimagic_zone,if=!death_knight.amz_specified&(death_knight.amz_absorb_percent>0&runic_power.deficit>70&talent.assimilation&(pet.gargoyle.active|!talent.summon_gargoyle))
    if S.AntiMagicZone:IsCastable() and (Player:RunicPowerDeficit() > 70 and S.Assimilation:IsAvailable() and (VarGargActive or not S.SummonGargoyle:IsAvailable())) then
      if Cast(S.AntiMagicZone, Settings.Commons2.GCDasOffGCD.AntiMagicZone) then return "antimagic_zone ams_amz 4"; end
    end
    -- antimagic_zone,if=death_knight.amz_specified&buff.amz_timing.up
    -- This is for Simc manually specified AMZ timing, so we're ignoring it.
  end
  -- invoke_external_buff,name=power_infusion,if=variable.st_planning&(pet.gargoyle.active&pet.gargoyle.remains<=22|!talent.summon_gargoyle&talent.army_of_the_dead&pet.army_ghoul.active&pet.army_ghoul.remains<=18|!talent.summon_gargoyle&!talent.army_of_the_dead&buff.dark_transformation.up|!talent.summon_gargoyle&buff.dark_transformation.up|!pet.gargoyle.active&cooldown.summon_gargoyle.remains+10>cooldown.invoke_external_buff_power_infusion.duration|active_enemies>=3&(buff.dark_transformation.up|death_and_decay.ticking))
  -- Note: Not handling external buffs.
  -- potion,if=(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(buff.dark_transformation.up&30>=buff.dark_transformation.remains|pet.army_ghoul.active&pet.army_ghoul.remains<=30|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=30)|fight_remains<=30
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected then
      if PotionSelected:IsReady() and ((not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (Pet:BuffUp(S.DarkTransformation) and 30 >= Pet:BuffRemains(S.DarkTransformation) or VarArmyGhoulActive and VarArmyGhoulRemains <= 30 or VarApocGhoulActive and VarApocGhoulRemains <= 30) or FightRemains <= 30) then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion high_prio_actions 2"; end
      end
    end
  end
  -- army_of_the_dead,if=!equipped.fyralath_the_dreamrender&(talent.summon_gargoyle&cooldown.summon_gargoyle.remains<2|!talent.summon_gargoyle|fight_remains<35)
  if S.ArmyoftheDead:IsReady() and (not I.Fyralath:IsEquipped() and (S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() < 2 or not S.SummonGargoyle:IsAvailable() or FightRemains < 35)) then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyOfTheDead) then return "army_of_the_dead high_prio_actions 4"; end
  end
  -- death_coil,if=(active_enemies<=3|!talent.epidemic)&(pet.gargoyle.active&talent.commander_of_the_dead&buff.commander_of_the_dead.up&cooldown.apocalypse.remains<5&buff.commander_of_the_dead.remains>27|debuff.death_rot.up&debuff.death_rot.remains<gcd)
  if S.DeathCoil:IsReady() and ((ActiveEnemies <= 3 or not S.Epidemic:IsAvailable()) and (VarGargActive and S.CommanderoftheDead:IsAvailable() and Player:BuffUp(S.CommanderoftheDeadBuff) and S.Apocalypse:CooldownRemains() < 5 and Player:BuffRemains(S.CommanderoftheDeadBuff) > 27 or Target:DebuffUp(S.DeathRotDebuff) and Target:DebuffRemains(S.DeathRotDebuff) < Player:GCD())) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil high_prio_actions 6"; end
  end
  -- epidemic,if=active_enemies>=4&(talent.commander_of_the_dead&buff.commander_of_the_dead.up&cooldown.apocalypse.remains<5|debuff.death_rot.up&debuff.death_rot.remains<gcd)
  if S.Epidemic:IsReady() and (ActiveEnemies >= 4 and (S.CommanderoftheDead:IsAvailable() and Player:BuffUp(S.CommanderoftheDeadBuff) and S.Apocalypse:CooldownRemains() < 5 or Target:DebuffUp(S.DeathRotDebuff) and Target:DebuffRemains(S.DeathRotDebuff) < Player:GCD())) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic high_prio_actions 8"; end
  end
  -- wound_spender,if=(cooldown.apocalypse.remains>variable.apoc_timing+3|cooldown.unholy_assault.ready|active_enemies>=3)&talent.plaguebringer&(talent.superstrain|talent.unholy_blight)&buff.plaguebringer.remains<gcd
  if WoundSpender:IsReady() and ((S.Apocalypse:CooldownRemains() > VarApocTiming + 3 or S.UnholyAssault:CooldownUp() or ActiveEnemies >= 3) and S.Plaguebringer:IsAvailable() and (S.Superstrain:IsAvailable() or S.UnholyBlight:IsAvailable()) and Player:BuffRemains(S.PlaguebringerBuff) < Player:GCD()) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender high_prio_actions 10"; end
  end
  -- unholy_blight,if=variable.st_planning&((!talent.apocalypse|cooldown.apocalypse.remains|!talent.summon_gargoyle)&talent.morbidity|!talent.morbidity)|variable.adds_remain|fight_remains<21
  if S.UnholyBlight:IsReady() and (VarSTPlanning and ((not S.Apocalypse:IsAvailable() or S.Apocalypse:CooldownDown() or not S.SummonGargoyle:IsAvailable()) and S.Morbidity:IsAvailable() or not S.Morbidity:IsAvailable()) or VarAddsRemain or FightRemains < 21) then
    if Cast(S.UnholyBlight, Settings.Unholy.GCDasOffGCD.UnholyBlight, nil, not Target:IsInRange(8)) then return "unholy_blight high_prio_actions 12"; end
  end
  -- outbreak,target_if=target.time_to_die>dot.virulent_plague.remains&(dot.virulent_plague.refreshable|talent.superstrain&(dot.frost_fever_superstrain.refreshable|dot.blood_plague_superstrain.refreshable))&(!talent.unholy_blight|talent.unholy_blight&cooldown.unholy_blight.remains>15%((talent.superstrain*3)+(talent.plaguebringer*2)+(talent.ebon_fever*2)))
  if S.Outbreak:IsReady() then
    if Everyone.CastCycle(S.Outbreak, EnemiesMelee, EvaluateCycleOutbreak, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak high_prio_actions 14"; end
  end
  -- army_of_the_dead,if=equipped.fyralath_the_dreamrender&(talent.summon_gargoyle&cooldown.summon_gargoyle.remains<2|!talent.summon_gargoyle|fight_remains<35)
  if S.ArmyoftheDead:IsReady() and (I.Fyralath:IsEquipped() and (S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() < 2 or not S.SummonGargoyle:IsAvailable() or FightRemains < 35)) then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyOfTheDead) then return "army_of_the_dead high_prio_actions 16"; end
  end
end

local function Racials()
  -- arcane_torrent,if=runic_power.deficit>20&(cooldown.summon_gargoyle.remains<gcd|!talent.summon_gargoyle.enabled|pet.gargoyle.active&rune<2&debuff.festering_wound.stack<1)
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 20 and (S.SummonGargoyle:CooldownRemains() < Player:GCD() or not S.SummonGargoyle:IsAvailable() or VarGargActive and Player:Rune() < 2 and FesterStacks < 1)) then
    if Cast(S.ArcaneTorrent, Settings.Commons2.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent racials 2"; end
  end
  -- blood_fury,if=(buff.blood_fury.duration+3>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=buff.blood_fury.duration+3|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.blood_fury.duration+3|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.blood_fury.duration+3
  if S.BloodFury:IsCastable() and ((S.BloodFury:BaseDuration() + 3 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= S.BloodFury:BaseDuration() + 3 or VarApocGhoulActive and VarApocGhoulRemains <= S.BloodFury:BaseDuration() + 3 or ActiveEnemies >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or FightRemains <= S.BloodFury:BaseDuration() + 3) then
    if Cast(S.BloodFury, Settings.Commons2.OffGCDasOffGCD.Racials) then return "blood_fury racials 4"; end
  end
  -- berserking,if=(buff.berserking.duration+3>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=buff.berserking.duration+3|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.berserking.duration+3|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.berserking.duration+3
  if S.Berserking:IsCastable() and ((S.Berserking:BaseDuration() + 3 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= S.Berserking:BaseDuration() + 3 or VarApocGhoulActive and VarApocGhoulRemains <= S.Berserking:BaseDuration() + 3 or ActiveEnemies >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or FightRemains <= S.Berserking:BaseDuration() + 3) then
    if Cast(S.Berserking, Settings.Commons2.OffGCDasOffGCD.Racials) then return "berserking racials 6"; end
  end
  -- lights_judgment,if=buff.unholy_strength.up&(!talent.festermight|buff.festermight.remains<target.time_to_die|buff.unholy_strength.remains<target.time_to_die)
  if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff) and (not S.Festermight:IsAvailable() or Player:BuffRemains(S.FestermightBuff) < Target:TimeToDie() or Player:BuffRemains(S.UnholyStrengthBuff) < Target:TimeToDie())) then
    if Cast(S.LightsJudgment, Settings.Commons2.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
  end
  -- ancestral_call,if=(18>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=18|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=18|active_enemies>=2&death_and_decay.ticking)|fight_remains<=18
  if S.AncestralCall:IsCastable() and ((18 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= 18 or VarApocGhoulActive and VarApocGhoulRemains <= 18 or ActiveEnemies >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or FightRemains <= 18) then
    if Cast(S.AncestralCall, Settings.Commons2.OffGCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
  end
  -- arcane_pulse,if=active_enemies>=2|(rune.deficit>=5&runic_power.deficit>=60)
  if S.ArcanePulse:IsCastable() and (ActiveEnemies >= 2 or (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
    if Cast(S.ArcanePulse, Settings.Commons2.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 12"; end
  end
  -- fireblood,if=(buff.fireblood.duration+3>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(pet.army_ghoul.active&pet.army_ghoul.remains<=buff.fireblood.duration+3|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.fireblood.duration+3|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.fireblood.duration+3
  if S.Fireblood:IsCastable() and ((S.Fireblood:BaseDuration() + 3 >= VarGargRemains and VarGargActive) or (not S.SummonGargoyle:IsAvailable() or S.SummonGargoyle:CooldownRemains() > 60) and (VarArmyGhoulActive and VarArmyGhoulRemains <= S.Fireblood:BaseDuration() + 3 or VarApocGhoulActive and VarApocGhoulRemains <= S.Fireblood:BaseDuration() + 3 or ActiveEnemies >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or FightRemains <= S.Fireblood:BaseDuration() + 3) then
    if Cast(S.Fireblood, Settings.Commons2.OffGCDasOffGCD.Racials) then return "fireblood racials 14"; end
  end
  -- bag_of_tricks,if=active_enemies=1&(buff.unholy_strength.up|fight_remains<5)
  if S.BagofTricks:IsCastable() and (ActiveEnemies == 1 and (Player:BuffUp(S.UnholyStrengthBuff) or HL.FilteredFightRemains(EnemiesMelee, "<", 5))) then
    if Cast(S.BagofTricks, Settings.Commons2.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks racials 16"; end
  end
end

local function ST()
  -- death_coil,if=!variable.epidemic_priority&(!variable.pooling_runic_power&variable.spend_rp|fight_remains<10)
  if S.DeathCoil:IsReady() and (not VarEpidemicPriority and (not VarPoolingRunicPower and VarSpendRP or FightRemains < 10)) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil st 2"; end
  end
  -- epidemic,if=variable.epidemic_priority&(!variable.pooling_runic_power&variable.spend_rp|fight_remains<10)
  if S.Epidemic:IsReady() and (VarEpidemicPriority and (not VarPoolingRunicPower and VarSpendRP or FightRemains < 10)) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(40)) then return "epidemic st 4"; end
  end
  -- any_dnd,if=!death_and_decay.ticking&(active_enemies>=2|talent.unholy_ground&(pet.apoc_ghoul.active&pet.apoc_ghoul.remains>=13|pet.gargoyle.active&pet.gargoyle.remains>8|pet.army_ghoul.active&pet.army_ghoul.remains>8|!variable.pop_wounds&debuff.festering_wound.stack>=4)|talent.defile&(pet.gargoyle.active|pet.apoc_ghoul.active|pet.army_ghoul.active|buff.dark_transformation.up))&(death_knight.fwounded_targets=active_enemies|active_enemies=1)
  if AnyDnD:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (ActiveEnemies >= 2 or S.UnholyGround:IsAvailable() and (VarApocGhoulActive and VarApocGhoulRemains >= 13 or VarGargActive and VarGargRemains > 8 or VarArmyGhoulActive and VarArmyGhoulRemains > 8 or not VarPopWounds and FesterStacks >= 4) or S.Defile:IsAvailable() and (VarGargActive or VarApocGhoulActive or VarArmyGhoulActive or Pet:BuffUp(S.DarkTransformation))) and (S.FesteringWoundDebuff:AuraActiveCount() == ActiveEnemies or ActiveEnemies == 1)) then
    if Cast(AnyDnD, Settings.Commons2.GCDasOffGCD.DeathAndDecay) then return "any_dnd st 6"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=variable.pop_wounds|active_enemies>=2&death_and_decay.ticking
  if WoundSpender:IsReady() and (VarPopWounds or ActiveEnemies >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender st 8"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=!variable.pop_wounds&debuff.festering_wound.stack<4
  if S.FesteringStrike:IsReady() and (not VarPopWounds) then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeST, not Target:IsInMeleeRange(5)) then return "festering_strike st 10"; end
  end
  -- death_coil
  if S.DeathCoil:IsReady() then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil st 12"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=!variable.pop_wounds&debuff.festering_wound.stack>=4
  if WoundSpender:IsReady() and (not VarPopWounds) then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrikeST2, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender st 14"; end
  end
end

local function Trinkets()
  -- use_item,name=fyralath_the_dreamrender,if=active_dot.mark_of_fyralath=active_enemies&(active_enemies<5|active_enemies>21|fight_remains<4)
  -- Note: Using >= for mark_of_fyralath debuff count, just to be safe.
  if Settings.Commons.Enabled.Items and I.Fyralath:IsEquippedAndReady() and (S.MarkofFyralathDebuff:AuraActiveCount() >= ActiveEnemies and (ActiveEnemies < 5 or ActiveEnemies > 21 or FightRemains < 4)) then
    if Cast(I.Fyralath, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(25)) then return "fyralath_the_dreamrender trinkets 1"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,name=algethar_puzzle_box,if=cooldown.summon_gargoyle.remains<5&rune<=4|!talent.summon_gargoyle&pet.army_ghoul.active|active_enemies>3&variable.adds_remain&(buff.dark_transformation.up|talent.bursting_sores&cooldown.any_dnd.remains<10&!death_and_decay.ticking)
    if I.AlgetharPuzzleBox:IsEquippedAndReady() and (S.SummonGargoyle:CooldownRemains() < 5 and Player:Rune() <= 4 or not S.SummonGargoyle:IsAvailable() and VarArmyGhoulActive or ActiveEnemies > 3 and VarAddsRemain and (Pet:BuffUp(S.DarkTransformation) or S.BurstingSores:IsAvailable() and AnyDnD:CooldownRemains() < 10 and Player:BuffDown(S.DeathAndDecayBuff))) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box trinkets 2"; end
    end
    -- use_item,use_off_gcd=1,name=irideus_fragment,if=(pet.gargoyle.active&pet.gargoyle.remains<16|!talent.summon_gargoyle&pet.army_ghoul.active&pet.army_ghoul.remains<16)|active_enemies>3&variable.adds_remain&(buff.dark_transformation.up|talent.bursting_sores&death_and_decay.ticking)
    if I.IrideusFragment:IsEquippedAndReady() and ((VarGargActive and VarGargRemains < 16 or not S.SummonGargoyle:IsAvailable() and VarArmyGhoulActive and VarArmyGhoulRemains < 16) or ActiveEnemies > 3 and VarAddsRemain and (Pet:BuffUp(S.DarkTransformation) or S.BurstingSores:IsAvailable() and Player:BuffUp(S.DeathAndDecayBuff))) then
      if Cast(I.IrideusFragment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "irideus_fragment trinkets 4"; end
    end
    -- use_item,use_off_gcd=1,name=vial_of_animated_blood,if=pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=18|!talent.apocalypse&buff.dark_transformation.up|active_enemies>3&variable.adds_remain&(buff.dark_transformation.up|talent.bursting_sores&death_and_decay.ticking)
    if I. VialofAnimatedBlood:IsEquippedAndReady() and (VarApocGhoulActive and VarApocGhoulRemains <= 18 or not S.Apocalypse:IsAvailable() and Pet:BuffUp(S.DarkTransformation) or ActiveEnemies > 3 and VarAddsRemain and (Pet:BuffUp(S.DarkTransformation) or S.BurstingSores:IsAvailable() and Player:BuffUp(S.DeathAndDecayBuff))) then
      if Cast(I.VialofAnimatedBlood, nil, Settings.Commons.DisplayStyle.Trinkets) then return "vial_of_animated_blood trinkets 6"; end
    end
  end
  -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_manual&variable.trinket_1_buffs&((!talent.summon_gargoyle&((!talent.army_of_the_dead|cooldown.army_of_the_dead.remains_expected>60|death_knight.disable_aotd)&(pet.apoc_ghoul.active|(!talent.apocalypse|active_enemies>=2)&buff.dark_transformation.up)|pet.army_ghoul.active)|talent.summon_gargoyle&pet.gargoyle.active|cooldown.summon_gargoyle.remains>80)&(pet.apoc_ghoul.active|(!talent.apocalypse|active_enemies>=2)&buff.dark_transformation.up)&(variable.trinket_2_exclude|variable.trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown))|trinket.1.proc.any_dps.duration>=fight_remains
  -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_manual&variable.trinket_2_buffs&((!talent.summon_gargoyle&((!talent.army_of_the_dead|cooldown.army_of_the_dead.remains_expected>60|death_knight.disable_aotd)&(pet.apoc_ghoul.active|(!talent.apocalypse|active_enemies>=2)&buff.dark_transformation.up)|pet.army_ghoul.active)|talent.summon_gargoyle&pet.gargoyle.active|cooldown.summon_gargoyle.remains>80)&(pet.apoc_ghoul.active|(!talent.apocalypse|active_enemies>=2)&buff.dark_transformation.up)&(variable.trinket_1_exclude|variable.trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown))|trinket.2.proc.any_dps.duration>=fight_remains
  -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_manual&!variable.trinket_1_buffs&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead|!talent.summon_gargoyle&talent.army_of_the_dead&cooldown.army_of_the_dead.remains_expected>20|!talent.summon_gargoyle&!talent.army_of_the_dead&cooldown.dark_transformation.remains>20|cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
  -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_manual&!variable.trinket_2_buffs&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown|!talent.summon_gargoyle&!talent.army_of_the_dead|!talent.summon_gargoyle&talent.army_of_the_dead&cooldown.army_of_the_dead.remains_expected>20|!talent.summon_gargoyle&!talent.army_of_the_dead&cooldown.dark_transformation.remains>20|cooldown.summon_gargoyle.remains>20&!pet.gargoyle.active)|fight_remains<15
  -- use_item,use_off_gcd=1,slot=main_hand,if=!equipped.fyralath_the_dreamrender&(!variable.trinket_1_buffs|trinket.1.cooldown.remains)&(!variable.trinket_2_buffs|trinket.2.cooldown.remains)
  -- TODO: Add above lines and remove below lines when we can handle the trinket sync/priority variables. For now, keeping the old trinket setup below.
  -- use_items,if=(cooldown.apocalypse.remains|buff.dark_transformation.up)
  if (S.Apocalypse:CooldownDown() or Pet:BuffUp(S.DarkTransformation)) then
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

local function Variables()
  -- variable,name=epidemic_priority,op=setif,value=1,value_else=0,condition=talent.improved_death_coil&!talent.coil_of_devastation&active_enemies>=3|talent.coil_of_devastation&active_enemies>=4|!talent.improved_death_coil&active_enemies>=2
  VarEpidemicPriority = (S.ImprovedDeathCoil:IsAvailable() and not S.CoilofDevastation:IsAvailable() and ActiveEnemies >= 3 or S.CoilofDevastation:IsAvailable() and ActiveEnemies >= 4 or not S.ImprovedDeathCoil:IsAvailable() and ActiveEnemies >= 2)
  -- variable,name=garg_setup_complete,op=setif,value=1,value_else=0,condition=active_enemies>=3|cooldown.summon_gargoyle.remains>1&(cooldown.apocalypse.remains>1|!talent.apocalypse)|!talent.summon_gargoyle|time>20
  VarGargSetupComplete = (ActiveEnemies >= 3 or S.SummonGargoyle:CooldownRemains() > 1 and (S.Apocalypse:CooldownRemains() > 1 or not S.Apocalypse:IsAvailable()) or not S.SummonGargoyle:IsAvailable() or HL.CombatTime() > 20)
  -- variable,name=apoc_timing,op=setif,value=7,value_else=2,condition=cooldown.apocalypse.remains<10&debuff.festering_wound.stack<=4&cooldown.unholy_assault.remains>10
  VarApocTiming = (S.Apocalypse:CooldownRemains() < 10 and FesterStacks <= 4 and S.UnholyAssault:CooldownRemains() > 10) and 7 or 2
  -- variable,name=festermight_tracker,op=setif,value=debuff.festering_wound.stack>=1,value_else=debuff.festering_wound.stack>=(3-talent.infected_claws),condition=!pet.gargoyle.active&talent.festermight&buff.festermight.up&(buff.festermight.remains%(5*gcd.max))>=1
  if (not VarGargActive and S.Festermight:IsAvailable() and Player:BuffUp(S.FestermightBuff) and (Player:BuffRemains(S.FestermightBuff) / (5 * Player:GCD())) >= 1) then
    VarFesterTracker = FesterStacks >= 1
  else
    VarFesterTracker = FesterStacks >= (3 - num(S.InfectedClaws:IsAvailable()))
  end
  -- variable,name=pop_wounds,op=setif,value=1,value_else=0,condition=(cooldown.apocalypse.remains>variable.apoc_timing|!talent.apocalypse)&(variable.festermight_tracker|debuff.festering_wound.stack>=1&cooldown.unholy_assault.remains<20&talent.unholy_assault&variable.st_planning|debuff.rotten_touch.up&debuff.festering_wound.stack>=1|debuff.festering_wound.stack>4|set_bonus.tier31_4pc&(pet.apoc_magus.active|pet.army_magus.active)&debuff.festering_wound.stack>=1)|fight_remains<5&debuff.festering_wound.stack>=1
  VarPopWounds = ((S.Apocalypse:CooldownRemains() > VarApocTiming or not S.Apocalypse:IsAvailable()) and (VarFesterTracker or FesterStacks >= 1 and S.UnholyAssault:CooldownRemains() < 20 and S.UnholyAssault:IsAvailable() and VarSTPlanning or Target:DebuffUp(S.RottenTouchDebuff) and FesterStacks >= 1 or FesterStacks > 4 or Player:HasTier(31, 4) and (Ghoul:ApocMagusActive() or Ghoul:ArmyMagusActive()) and FesterStacks >= 1) or FightRemains < 5 and FesterStacks >= 1)
  -- variable,name=pooling_runic_power,op=setif,value=1,value_else=0,condition=talent.vile_contagion&cooldown.vile_contagion.remains<3&runic_power<60&!variable.st_planning
  VarPoolingRunicPower = (S.VileContagion:IsAvailable() and S.VileContagion:CooldownRemains() < 3 and Player:RunicPower() < 60 and not VarSTPlanning)
  -- variable,name=st_planning,op=setif,value=1,value_else=0,condition=active_enemies=1&(!raid_event.adds.exists|raid_event.adds.in>15)
  VarSTPlanning = (ActiveEnemies == 1 or not AoEON())
  -- variable,name=adds_remain,op=setif,value=1,value_else=0,condition=active_enemies>=2&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>6)
  VarAddsRemain = (ActiveEnemies >= 2 and AoEON())
  -- variable,name=spend_rp,op=setif,value=1,value_else=0,condition=(!talent.rotten_touch|talent.rotten_touch&!debuff.rotten_touch.up|runic_power.deficit<20)&(!set_bonus.tier31_4pc|set_bonus.tier31_4pc&!(pet.apoc_magus.active|pet.army_magus.active)|runic_power.deficit<20|rune<3)&((talent.improved_death_coil&(active_enemies=2|talent.coil_of_devastation)|rune<3|pet.gargoyle.active|buff.sudden_doom.react|cooldown.apocalypse.remains<10&debuff.festering_wound.stack>3|!variable.pop_wounds&debuff.festering_wound.stack>=4))
  VarSpendRP = (not S.RottenTouch:IsAvailable() or S.RottenTouch:IsAvailable() and Target:DebuffDown(S.RottenTouchDebuff) or Player:RunicPowerDeficit() < 20) and (not Player:HasTier(31, 4) or Player:HasTier(31, 4) and not (Ghoul:ApocMagusActive() or Ghoul:ArmyMagusActive()) or Player:RunicPowerDeficit() < 20 or Player:Rune() < 3) and (S.ImprovedDeathCoil:IsAvailable() and (ActiveEnemies == 2 or S.CoilofDevastation:IsAvailable()) or Player:Rune() < 3 or VarGargActive or Player:BuffUp(S.SuddenDoomBuff) or S.Apocalypse:CooldownRemains() < 10 and FesterStacks > 3 or not VarPopWounds and FesterStacks >= 4)
end

--- ======= ACTION LISTS =======
local function APL()
  no_heal = not DeathStrikeHeal()
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
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady() and not no_heal then
      if Cast(S.DeathStrike) then return "death_strike low hp or proc"; end
    end
    -- auto_attack
    -- Interrupts (here instead of HighPrioActions)
    local ShouldReturn = Everyone.Interrupt(S.MindFreeze, Settings.Commons2.OffGCDasOffGCD.MindFreeze, StunInterrupts); if ShouldReturn then return ShouldReturn; end
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
    -- call_action_list,name=high_prio_actions
    local ShouldReturn = HighPrioActions(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials
    if (CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=garg_setup,if=variable.garg_setup_complete=0
    if CDsON() and not VarGargSetupComplete then
      local ShouldReturn = GargSetup(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for GargSetup()"; end
    end
    -- call_action_list,name=cooldowns,if=variable.st_planning
    if (CDsON() and VarSTPlanning) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_cooldowns,if=variable.adds_remain
    if (AoEON() and CDsON() and VarAddsRemain) then
      local ShouldReturn = AoECDs(); if ShouldReturn then return ShouldReturn; end
    end
    if (AoEON()) then
      -- call_action_list,name=aoe_setup,if=variable.adds_remain&cooldown.any_dnd.remains<10&!death_and_decay.ticking
      if (VarAddsRemain and AnyDnD:CooldownRemains() < 10 and Player:BuffDown(S.DeathAndDecayBuff)) then
        local ShouldReturn = AoESetup(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=aoe_burst,if=active_enemies>=4&death_and_decay.ticking
      if (ActiveEnemies >= 4 and Player:BuffUp(S.DeathAndDecayBuff)) then
        local ShouldReturn = AoEBurst(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=aoe,if=active_enemies>=4&(cooldown.any_dnd.remains>10&!death_and_decay.ticking|!variable.adds_remain)
      if (ActiveEnemies >= 4 and (AnyDnD:CooldownRemains() > 10 and Player:BuffDown(S.DeathAndDecayBuff) or not VarAddsRemain)) then
        local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- call_action_list,name=st,if=active_enemies<=3
    if (ActiveEnemies <= 3) then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- Add pool resources icon if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool_resources"; end
  end
end

local function Init()
  S.VirulentPlagueDebuff:RegisterAuraTracking()
  S.FesteringWoundDebuff:RegisterAuraTracking()
  S.MarkofFyralathDebuff:RegisterAuraTracking()

  HR.Print("Unholy DK rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(252, APL, Init)
