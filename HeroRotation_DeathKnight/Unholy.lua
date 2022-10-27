--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Boss       = Unit.Boss
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
-- lua
local tableinsert = table.insert

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Unholy
local I = Item.DeathKnight.Unholy

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  --  I.TrinketName:ID(),
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
  Unholy = HR.GUISettings.APL.DeathKnight.Unholy
}

-- Variables
local VarApocTiming
local VarGargPooling
local VarFesterTracker
local VarBuildWounds
local VarPopWounds
local VarPoolingRunicPower
local VarPoolingRunes
local VarSTPlanning
local VarAddsRemain
local VarApocGhoulActive, VarApocGhoulRemains
local VarArmyGhoulActive, VarArmyGhoulRemains
local WoundSpender
local AnyDnD
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority
local FesterStacks
local BossFightRemains = 11111
local FightRemains = 11111
local ghoul = HL.GhoulTable

-- Enemies Variables
local EnemiesMelee, EnemiesMeleeCount
local Enemies10ySplash, Enemies10ySplashCount
local EnemiesWithoutVP

-- Legendaries
local SuperstrainEquipped = Player:HasLegendaryEquipped(30)
local PhearomonesEquipped = Player:HasLegendaryEquipped(31)
local DeadliestCoilEquipped = Player:HasLegendaryEquipped(45)
local DeathsCertaintyEquipped = Player:HasLegendaryEquipped(44)
local RampantTransferenceEquipped = Player:HasLegendaryEquipped(210)
local AbominationsFrenzyEquipped = Player:HasLegendaryEquipped(213)

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- Stun Interrupts List
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

-- Event Registrations
HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
  SuperstrainEquipped = Player:HasLegendaryEquipped(30)
  PhearomonesEquipped = Player:HasLegendaryEquipped(31)
  DeadliestCoilEquipped = Player:HasLegendaryEquipped(45)
  DeathsCertaintyEquipped = Player:HasLegendaryEquipped(44)
  RampantTransferenceEquipped = Player:HasLegendaryEquipped(210)
  AbominationsFrenzyEquipped = Player:HasLegendaryEquipped(213)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

--Functions
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

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

local function EvaluateTargetIfFilterFWStack(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff))
end

local function EvaluateTargetIfApocalypse(TargetUnit)
  -- if=debuff.festering_wound.up&variable.adds_remain&!death_and_decay.ticking&cooldown.death_and_decay.remains&rune<3|death_and_decay.ticking&rune=0
  return (TargetUnit:DebuffUp(S.FesteringWoundDebuff) and VarAddsRemain and Player:BuffDown(S.DeathAndDecayBuff) and S.DeathAndDecay:CooldownRemains() < 3 or Player:BuffUp(S.DeathAndDecayBuff) and Player:Rune() == 0)
end

local function EvaluateTargetIfApocalypse2(TargetUnit)
  -- if=active_enemies<=3&debuff.festering_wound.stack>=4&(talent.summon_gargoyle&cooldown.summon_gargoyle.remains|!talent.summon_gargoyle|talent.unholy_assault)|fight_remains<15
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4 and (S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownDown() or (not S.SummonGargoyle:IsAvailable()) or S.UnholyAssault:IsAvailable()) or FightRemains < 15)
end

local function EvaluateTargetIfSoulReaper(TargetUnit)
  -- if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  return (TargetUnit:TimeToX(35) < 5 and TargetUnit:TimeToDie() > (TargetUnit:DebuffRemains(S.SoulReaper) + 5))
end

local function EvaluateTargetIfFesteringStrike(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 4)
end

local function EvaluateTargetIfUnholyAssault(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 2)
end

--[[local function EvaluateTargetIfFilterSoulReaper(TargetUnit)
  return (TargetUnit:DebuffRemains(S.SoulReaper))
end

local function EvaluateTargetIfApocalypse(TargetUnit)
  return (EnemiesMeleeCount >= 2 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4 and Player:BuffDown(S.DeathAndDecayBuff))
end

local function EvaluateTargetIfFesteringStrike(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 3 and S.Apocalypse:CooldownRemains() < 3)
end

local function EvaluateTargetIfFesteringStrike2(TargetUnit)
  return (Player:RuneTimeToX(4) < AnyDnD:CooldownRemains())
end

local function EvaluateTargetIfFesteringStrike3(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 3 and S.Apocalypse:CooldownRemains() < 5 or TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 1)
end

local function EvaluateTargetIfFesteringStrike4(TargetUnit)
  return (S.Apocalypse:CooldownRemains() > 5 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 1)
end

local function EvaluateTargetIfWoundSpender(TargetUnit)
  return ((S.Apocalypse:CooldownRemains() > 15 and TargetUnit:DebuffUp(S.FesteringWoundDebuff) or TargetUnit:DebuffStack(S.FesteringWoundDebuff) > 4) and (HL.FilteredFightRemains(EnemiesMelee, "<", AnyDnD:CooldownRemains() + 10) or HL.FilteredFightRemains(EnemiesMelee, ">", S.Apocalypse:CooldownRemains())))
end

local function EvaluateCycleFesteringStrike(TargetUnit)
  return (TargetUnit:DebuffDown(S.FesteringWoundDebuff))
end]]

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
  -- army_of_the_dead,precombat_time=1.5*gcd
  if S.ArmyoftheDead:IsReady() and (not Settings.Unholy.DisableAotD) then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyoftheDead) then return "army_of_the_dead precombat 4"; end
  end
  -- fleshcraft
  if S.Fleshcraft:IsCastable() then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 3"; end
  end
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(trinket.1.cooldown.duration%%45=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(trinket.2.cooldown.duration%%45=0)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!trinket.1.has_use_buff&trinket.2.has_use_buff|trinket.2.has_use_buff&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- TODO: Trinket sync/priority stuff. Currently unable to pull trinket CD durations because WoW's API is bad.
  -- Manually added: festering_strike if in melee range
  if S.FesteringStrike:IsReady() and Target:IsSpellInRange(S.FesteringStrike) then
    if Cast(S.FesteringStrike) then return "festering_strike precombat 6"; end
  end
  -- Manually added: outbreak if not in melee range
  if S.Outbreak:IsReady() then
    if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak precombat 8"; end
  end
end

local function AoE()
  -- any_dnd,if=!death_and_decay.ticking&variable.adds_remain&(talent.festermight&buff.festermight.remains<3|!talent.festermight)&(death_knight.fwounded_targets=active_enemies|death_knight.fwounded_targets=8|!talent.bursting_sores&!talent.vile_contagion|raid_event.adds.exists&raid_event.adds.remains<=11&raid_event.adds.remains>5|(cooldown.vile_contagion.remains|!talent.vile_contagion)&buff.dark_transformation.up&talent.infected_claws&(buff.empower_rune_weapon.up|buff.unholy_assault.up))|fight_remains<10
  if AnyDnD:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and VarAddsRemain and (S.Festermight:IsAvailable() and Player:BuffRemains(S.FestermightBuff) < 3 or not S.Festermight:IsAvailable()) and (S.FesteringWoundDebuff:AuraActiveCount() == EnemiesMeleeCount or S.FesteringWoundDebuff:AuraActiveCount() == 8 or (not S.BurstingSores:IsAvailable()) and (not S.VileContagion:IsAvailable()) or (S.VileContagion:CooldownDown() or not S.VileContagion:IsAvailable()) and Pet:BuffUp(S.DarkTransformation) and S.InfectedClaws:IsAvailable() and (Player:BuffUp(S.EmpowerRuneWeaponBuff) or Player:BuffUp(S.UnholyAssaultBuff))) or FightRemains < 10) then
    if AnyDnD == S.DeathsDue then
      if Cast(AnyDnD, nil, Settings.Commons.DisplayStyle.Covenant) then return "any_dnd aoe 2"; end
    else
      if Cast(AnyDnD, Settings.Commons.GCDasOffGCD.DeathAndDecay) then return "any_dnd aoe 4"; end
    end
  end
  -- abomination_limb_talent,if=rune=0&variable.adds_remain
  if S.AbominationLimb:IsCastable() and (Player:Rune() == 0 and VarAddsRemain) then
    if Cast(S.AbominationLimb, Settings.Commons.GCDasOffGCD.AbominationLimb) then return "abomination_limb aoe 6"; end
  end
  -- apocalypse,target_if=min:debuff.festering_wound.stack,if=debuff.festering_wound.up&variable.adds_remain&!death_and_decay.ticking&cooldown.death_and_decay.remains&rune<3|death_and_decay.ticking&rune=0
  if S.Apocalypse:IsCastable() then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfApocalypse, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.Apocalypse) then return "apocalypse aoe 8"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=!death_and_decay.ticking&debuff.festering_wound.stack<4&(cooldown.vile_contagion.remains<5|cooldown.apocalypse.ready&cooldown.any_dnd.remains)
  if S.FesteringStrike:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (S.VileContagion:CooldownRemains() < 5 or S.Apocalypse:CooldownUp() and AnyDnD:CooldownDown())) then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrike, not Target:IsInMeleeRange(5)) then return "festering_strike aoe 10"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=!death_and_decay.ticking&(cooldown.vile_contagion.remains>5|!talent.vile_contagion)
  if S.FesteringStrike:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (S.VileContagion:CooldownRemains() > 5 or not S.VileContagion:IsAvailable())) then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5)) then return "festering_strike aoe 12"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=death_and_decay.ticking
  if WoundSpender:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff)) then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5)) then return "wound_spender aoe 14"; end
  end
  -- death_coil,if=!variable.pooling_runic_power&(rune<2&active_enemies<2+(talent.improved_death_coil+talent.coil_of_devastation+talent.rotten_touch)|!talent.epidemic)
  if S.DeathCoil:IsReady() and ((not VarPoolingRunicPower) and (Player:Rune() < 2 and EnemiesMeleeCount < 2 + (num(S.ImprovedDeathCoil:IsAvailable()) + num(S.CoilofDevastation:IsAvailable()) + num(S.RottenTouch:IsAvailable())) or not S.Epidemic:IsAvailable())) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil aoe 16"; end
  end
  -- epidemic,if=!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Commons.GCDasOffGCD.Epidemic, nil, not Target:IsSpellInRange(S.Epidemic)) then return "epidemic aoe 18"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=cooldown.death_and_decay.remains>10
  if WoundSpender:IsReady() and (S.DeathAndDecay:CooldownRemains() > 10) then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5)) then return "wound_spender aoe 20"; end
  end
end

local function Cooldowns()
  -- potion,if=(30>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(buff.dark_transformation.up&30>=buff.dark_transformation.remains|pet.army_ghoul.active&pet.army_ghoul.remains<=30|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=30)|fight_remains<=30
  if I.PotionofSpectralStrength:IsReady() and Settings.Commons.Enabled.Potions and ((30 >= ghoul:gargremains() and ghoul:gargactive()) or ((not S.SummonGargoyle:IsAvailable()) or S.SummonGargoyle:CooldownRemains() > 60) and (Pet:BuffUp(S.DarkTransformation) and 30 >= Pet:BuffRemains(S.DarkTransformation) or VarArmyGhoulActive and VarArmyGhoulRemains <= 30 or VarApocGhoulActive and VarApocGhoulRemains <= 30) or FightRemains <= 30) then
    if Cast(I.PotionofSpectralStrength, Settings.Commons.OffGCDasOffGCD.Potions) then return "potion cooldowns 2"; end
  end
  -- army_of_the_dead,if=talent.commander_of_the_dead&cooldown.dark_transformation.remains_expected<4|!talent.commander_of_the_dead&talent.unholy_assault&cooldown.unholy_assault.remains<10|!talent.unholy_assault&!talent.commander_of_the_dead|fight_remains<=30
  if S.ArmyoftheDead:IsReady() and (not Settings.Unholy.DisableAotD) and (S.CommanderoftheDead:IsAvailable() and S.DarkTransformation:CooldownRemains() < 4 or (not S.CommanderoftheDead:IsAvailable()) and S.UnholyAssault:IsAvailable() and S.UnholyAssault:CooldownRemains() < 10 or (not S.UnholyAssault:IsAvailable()) and (not S.CommanderoftheDead:IsAvailable()) or FightRemains <= 30) then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyoftheDead) then return "army_of_the_dead cooldowns 4"; end
  end
  -- vile_contagion,target_if=max:debuff.festering_wound.stack,if=active_enemies>=2&debuff.festering_wound.stack>=4&cooldown.any_dnd.remains<3
  if S.VileContagion:IsReady() and (Enemies10ySplashCount >= 2 and AnyDnD:CooldownRemains() < 3) then
    if Everyone.CastTargetIf(S.VileContagion, Enemies10ySplash, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfVileContagion, not Target:IsSpellInRange(S.VileContagion), Settings.Unholy.GCDasOffGCD.VileContagion) then return "vile_contagion cooldowns 6"; end
  end
  -- raise_dead,if=!pet.ghoul.active
  if S.RaiseDead:IsCastable() then
    if Settings.Unholy.RaiseDeadCastLeft then
      if HR.CastLeft(S.RaiseDead) then return "raise_dead cooldowns 8 left"; end
    else
      if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead cooldowns 8 displaystyle"; end
    end
  end
  -- summon_gargoyle,if=runic_power.deficit<60&(cooldown.dark_transformation.ready|buff.commander_of_the_dead_window.up|!talent.commander_of_the_dead)
  if S.SummonGargoyle:IsReady() and (Player:RunicPowerDeficit() < 60 and (S.DarkTransformation:CooldownUp() or S.CommanderoftheDead:TimeSinceLastCast() <= 4 or not S.CommanderoftheDead:IsAvailable())) then
    if Cast(S.SummonGargoyle, Settings.Unholy.GCDasOffGCD.SummonGargoyle) then return "summon_gargoyle cooldowns 10"; end
  end
  -- dark_transformation,if=variable.st_planning&(fight_remains<30|!talent.unholy_command|talent.unholy_command&(!talent.unholy_command.rank=2|pet.gargoyle.active|!talent.apocalypse|(pet.apoc_ghoul.active|cooldown.apocalypse.remains<1&debuff.festering_wound.stack>=4)&(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>4)))
  if S.DarkTransformation:IsCastable() and (VarSTPlanning and (FightRemains < 30 or (not S.UnholyCommand:IsAvailable()) or S.UnholyCommand:IsAvailable() and (S.UnholyCommand:TalentRank() ~= 2 or ghoul:gargactive() or (not S.Apocalypse:IsAvailable()) or (VarApocGhoulActive or S.Apocalypse:CooldownRemains() < 1 and FesterStacks >= 4) and ((not S.SummonGargoyle:IsAvailable()) or S.SummonGargoyle:CooldownRemains() > 4)))) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cooldowns 12"; end
  end
  -- dark_transformation,if=variable.adds_remain&(cooldown.any_dnd.remains<10&talent.infected_claws&((cooldown.vile_contagion.remains|raid_event.adds.exists&raid_event.adds.in>10)&death_knight.fwounded_targets<active_enemies|!talent.vile_contagion)&(raid_event.adds.remains>5|!raid_event.adds.exists)|!talent.infected_claws)|fight_remains<25
  if S.DarkTransformation:IsCastable() and (VarAddsRemain and (AnyDnD:CooldownRemains() < 10 and S.InfectedClaws:IsAvailable() and (S.VileContagion:CooldownDown() and S.FesteringWoundDebuff:AuraActiveCount() < EnemiesMeleeCount or not S.VileContagion:IsAvailable()) or not S.InfectedClaws:IsAvailable()) or FightRemains < 25) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cooldowns 14"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and Target:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaper) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsSpellInRange(S.SoulReaper)) then return "soul_reaper cooldowns 16"; end
  end
  -- soul_reaper,target_if=min:dot.soul_reaper.remains,if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount >= 2) then
    if Everyone.CastTargetIf(S.SoulReaper, EnemiesMelee, "min", EvaluateTargetIfFilterSoulReaper, EvaluateTargetIfSoulReaper, not Target:IsSpellInRange(S.SoulReaper)) then return "soul_reaper cooldowns 18"; end
  end
  -- unholy_blight,if=variable.st_planning&((!talent.apocalypse|cooldown.apocalypse.remains)&talent.morbidity|!talent.morbidity)
  if S.UnholyBlight:IsReady() and (VarSTPlanning and (((not S.Apocalypse:IsAvailable()) or S.Apocalypse:CooldownDown()) and S.Morbidity:IsAvailable() or not S.Morbidity:IsAvailable())) then
    if Cast(S.UnholyBlight, Settings.Unholy.GCDasOffGCD.UnholyBlight, nil, not Target:IsInRange(8)) then return "unholy_blight cooldowns 20"; end
  end
  -- unholy_blight,if=variable.adds_remain|fight_remains<21
  if S.UnholyBlight:IsReady() and (VarAddsRemain or FightRemains < 21) then
    if Cast(S.UnholyBlight, Settings.Unholy.GCDasOffGCD.UnholyBlight, nil, not Target:IsInRange(8)) then return "unholy_blight cooldowns 22"; end
  end
  -- unholy_assault,if=variable.st_planning&(!talent.apocalypse|cooldown.apocalypse.remains<3&(cooldown.summon_gargoyle.remains&!pet.gargoyle.active&talent.summon_gargoyle|!talent.summon_gargoyle)|(buff.unholy_assault.duration>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(buff.dark_transformation.up&buff.unholy_assault.duration>=buff.dark_transformation.remains|pet.army_ghoul.active&pet.army_ghoul.remains<=buff.unholy_assault.duration|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.unholy_assault.duration))|fight_remains<21
  if S.UnholyAssault:IsReady() and (VarSTPlanning and ((not S.Apocalypse:IsAvailable()) or S.Apocalypse:CooldownRemains() < 3 and (S.SummonGargoyle:CooldownDown() and (not ghoul:gargactive()) and S.SummonGargoyle:IsAvailable() or not S.SummonGargoyle:IsAvailable()) or (12 >= ghoul:gargremains() and ghoul:gargactive()) or ((not S.SummonGargoyle:IsAvailable()) or S.SummonGargoyle:CooldownRemains() > 60) and (Pet:BuffUp(S.DarkTransformation) and 12 >= Pet:BuffRemains(S.DarkTransformation) or VarArmyGhoulActive and VarArmyGhoulRemains <= 12 or VarApocGhoulActive and VarApocGhoulRemains <= 12)) or FightRemains < 21) then
    if Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault, nil, not Target:IsInMeleeRange(5)) then return "unholy_assault cooldowns 24"; end
  end
  -- unholy_assault,target_if=min:debuff.festering_wound.stack,if=active_enemies>=2&debuff.festering_wound.stack<=2&(talent.vile_contagion&cooldown.vile_contagion.remains<gcd&cooldown.any_dnd.remains<3|buff.dark_transformation.up|cooldown.death_and_decay.remains<gcd)
  if S.UnholyAssault:IsReady() and (Enemies10ySplashCount >= 2 and (S.VileContagion:IsAvailable() and S.VileContagion:CooldownRemains() < Player:GCD() and AnyDnD:CooldownRemains() < 3 or Pet:BuffUp(S.DarkTransformation) or S.DeathAndDecay:CooldownRemains() < Player:GCD())) then
    if Everyone.CastTargetIf(S.UnholyAssault, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfUnholyAssault, not Target:IsInMeleeRange(5), Settings.Unholy.GCDasOffGCD.UnholyAssault) then return "unholy_assault cooldowns 26"; end
  end
  -- apocalypse,target_if=max:debuff.festering_wound.stack,if=active_enemies<=3&debuff.festering_wound.stack>=4&(talent.summon_gargoyle&cooldown.summon_gargoyle.remains|!talent.summon_gargoyle|talent.unholy_assault)|fight_remains<15
  if S.Apocalypse:IsCastable() and (Enemies10ySplashCount <= 3) then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfApocalypse2, not Target:IsInMeleeRange(5)) then return "apocalypse cooldowns 28"; end
  end
  -- empower_rune_weapon,if=variable.st_planning&runic_power.deficit>20&(pet.gargoyle.active&pet.apoc_ghoul.active|!talent.summon_gargoyle&talent.army_of_the_damned&pet.army_ghoul.active&pet.apoc_ghoul.active|!talent.summon_gargoyle&!talent.army_of_the_damned&buff.dark_transformation.up|!talent.summon_gargoyle&!talent.summon_gargoyle&buff.dark_transformation.up)|fight_remains<=21
  if S.EmpowerRuneWeapon:IsCastable() and (VarSTPlanning and Player:RunicPowerDeficit() > 20 and (ghoul:gargactive() and VarApocGhoulActive or (not S.SummonGargoyle:IsAvailable()) and S.ArmyoftheDamned:IsAvailable() and VarArmyGhoulActive and VarApocGhoulActive or (not S.SummonGargoyle:IsAvailable()) and (not S.ArmyoftheDamned:IsAvailable()) and Pet:BuffUp(S.DarkTransformation) or (not S.SummonGargoyle:IsAvailable()) and Pet:BuffUp(S.DarkTransformation)) or FightRemains <= 21) then
    if Cast(S.EmpowerRuneWeapon, Settings.Commons.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 30"; end
  end
  -- empower_rune_weapon,if=variable.adds_remain&buff.dark_transformation.up
  if S.EmpowerRuneWeapon:IsCastable() and (VarAddsRemain and Pet:BuffUp(S.DarkTransformation)) then
    if Cast(S.EmpowerRuneWeapon, Settings.Commons.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon cooldowns 32"; end
  end
  -- abomination_limb_talent,if=variable.st_planning&rune<3
  if S.AbominationLimb:IsCastable() and (VarSTPlanning and Player:Rune() < 3) then
    if Cast(S.AbominationLimb, Settings.Commons.GCDasOffGCD.AbominationLimb) then return "abomination_limb cooldowns 34"; end
  end
  -- sacrificial_pact,if=active_enemies>=2&!buff.dark_transformation.up&cooldown.dark_transformation.remains>6|fight_remains<gcd
  if S.SacrificialPact:IsReady() and (EnemiesMeleeCount >= 2 and Pet:BuffDown(S.DarkTransformation) and S.DarkTransformation:CooldownRemains() > 6 or FightRemains < Player:GCD()) then
    if Cast(S.SacrificialPact, Settings.Commons.GCDasOffGCD.SacrificialPact, nil, not Target:IsInRange(8)) then return "sacrificial_pact cooldowns 36"; end
  end
end

local function Covenants()
  -- swarming_mist,if=variable.st_planning&runic_power.deficit>16&(cooldown.apocalypse.remains|!talent.army_of_the_damned&cooldown.dark_transformation.remains)|fight_remains<11
  if S.SwarmingMist:IsReady() and CDsON() and (VarSTPlanning and Player:RunicPowerDeficit() > 16 and (not S.Apocalypse:CooldownUp() or not S.ArmyoftheDamned:IsAvailable() and not S.DarkTransformation:CooldownUp()) or HL.FilteredFightRemains(EnemiesMelee, "<", 11)) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(10)) then return "swarming_mist covenants 2"; end
  end
  -- swarming_mist,if=cooldown.apocalypse.remains&(active_enemies>=2&active_enemies<=5&runic_power.deficit>10+(active_enemies*6)&variable.adds_remain|active_enemies>5&runic_power.deficit>40)
  if S.SwarmingMist:IsReady() and CDsON() and (S.Apocalypse:CooldownDown() and (EnemiesMeleeCount >= 2 and EnemiesMeleeCount <= 5 and Player:RunicPowerDeficit() > 10 + (EnemiesMeleeCount * 6) and VarAddsRemain or EnemiesMeleeCount > 5 and Player:RunicPowerDeficit() > 40)) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(10)) then return "swarming_mist covenants 4"; end
  end
  -- abomination_limb_covenant,if=variable.st_planning&!soulbind.lead_by_example&(cooldown.apocalypse.remains|!talent.army_of_the_damned&cooldown.dark_transformation.remains)&rune.time_to_4>buff.runic_corruption.remains|fight_remains<12+(soulbind.kevins_oozeling*28)
  if S.AbominationLimbCov:IsReady() and CDsON() and (VarSTPlanning and not S.LeadByExample:SoulbindEnabled() and (not S.Apocalypse:CooldownUp() or not S.ArmyoftheDamned:IsAvailable() and not S.DarkTransformation:CooldownUp()) and Player:RuneTimeToX(4) > Player:BuffRemains(S.RunicCorruptionBuff) or HL.FilteredFightRemains(EnemiesMelee, "<", 12 + (num(S.KevinsOozeling:SoulbindEnabled()) * 28))) then
    if Cast(S.AbominationLimbCov, nil, Settings.Commons.DisplayStyle.Covenant) then return "abomination_limb covenants 6"; end
  end
  -- abomination_limb,if=variable.st_planning&soulbind.lead_by_example&(dot.unholy_blight_dot.remains>11|!talent.unholy_blight&cooldown.dark_transformation.remains)
  if S.AbominationLimbCov:IsReady() and CDsON() and (VarSTPlanning and S.LeadByExample:SoulbindEnabled() and (Target:DebuffRemains(S.UnholyBlightDebuff) > 11 or not S.UnholyBlight:IsAvailable() and not S.DarkTransformation:CooldownUp())) then
    if Cast(S.AbominationLimbCov, nil, Settings.Commons.DisplayStyle.Covenant) then return "abomination_limb covenants 8"; end
  end
  -- abomination_limb,if=variable.st_planning&soulbind.kevins_oozeling&(debuff.festering_wound.stack>=4&!runeforge.abominations_frenzy|runeforge.abominations_frenzy&cooldown.apocalypse.remains)
  if S.AbominationLimbCov:IsReady() and CDsON() and (VarSTPlanning and S.KevinsOozeling:SoulbindEnabled() and (Target:DebuffStack(S.FesteringWoundDebuff) >= 4 and (not AbominationsFrenzyEquipped) or AbominationsFrenzyEquipped and S.Apocalypse:CooldownDown())) then
    if Cast(S.AbominationLimbCov, nil, Settings.Commons.DisplayStyle.Covenant) then return "abomination_limb covenants 9"; end
  end
  -- abomination_limb,if=variable.adds_remain&rune.time_to_4>buff.runic_corruption.remains
  if S.AbominationLimbCov:IsReady() and CDsON() and (VarAddsRemain and Player:RuneTimeToX(4) > Player:BuffRemains(S.RunicCorruptionBuff)) then
    if Cast(S.AbominationLimbCov, nil, Settings.Commons.DisplayStyle.Covenant) then return "abomination_limb covenants 10"; end
  end
  -- shackle_the_unworthy,if=variable.st_planning&(cooldown.apocalypse.remains>10|!talent.army_of_the_damned&cooldown.dark_transformation.remains)|fight_remains<15
  if S.ShackleTheUnworthy:IsCastable() and (VarSTPlanning and (S.Apocalypse:CooldownRemains() > 10 or not S.ArmyoftheDamned:IsAvailable() and not S.DarkTransformation:CooldownUp()) or HL.FilteredFightRemains(EnemiesMelee, "<", 15)) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ShackleTheUnworthy)) then return "shackle_the_unworthy covenants 12"; end
  end
  -- shackle_the_unworthy,if=variable.adds_remain&(death_and_decay.ticking|raid_event.adds.remains<=14)
  if S.ShackleTheUnworthy:IsCastable() and (VarAddsRemain and (Player:BuffUp(S.DeathAndDecayBuff) or AddsFightRemains(Enemies10ySplash) <= 14)) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ShackleTheUnworthy)) then return "shackle_the_unworthy covenants 14"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent&!buff.volatile_solvent_humanoid.up,interrupt_immediate=1,interrupt_global=1,interrupt_if=soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft covenants 16"; end
  end
end

local function Racials()
  -- arcane_torrent,if=runic_power.deficit>20&(pet.gargoyle.active|!talent.summon_gargoyle.enabled)
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 20 and (VarGargoyleActive or not S.SummonGargoyle:IsAvailable())) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 2"; end
  end
  -- blood_fury,if=(buff.blood_fury.duration>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(buff.dark_transformation.up&buff.blood_fury.duration>=buff.dark_transformation.remains|pet.army_ghoul.active&pet.army_ghoul.remains<=buff.blood_fury.duration|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.blood_fury.duration|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.blood_fury.duration
  if S.BloodFury:IsCastable() and ((S.BloodFury:BaseDuration() >= ghoul:gargremains() and ghoul:gargactive()) or ((not S.SummonGargoyle:IsAvailable()) or S.SummonGargoyle:CooldownRemains() > 60) and (Pet:BuffUp(S.DarkTransformation) and S.BloodFury:BaseDuration() >= Pet:BuffRemains(S.DarkTransformation) or VarArmyGhoulActive and VarArmyGhoulRemains <= S.BloodFury:BaseDuration() or VarApocGhoulActive and VarApocGhoulRemains <= S.BloodFury:BaseDuration() or Enemies10ySplashCount >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or FightRemains <= S.BloodFury:BaseDuration()) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 4"; end
  end
  -- berserking,if=(buff.berserking.duration>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(buff.dark_transformation.up&buff.berserking.duration>=buff.dark_transformation.remains|pet.army_ghoul.active&pet.army_ghoul.remains<=buff.berserking.duration|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.berserking.duration|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.berserking.duration
  if S.Berserking:IsCastable() and ((S.Berserking:BaseDuration() >= ghoul:gargremains() and ghoul:gargactive()) or ((not S.SummonGargoyle:IsAvailable()) or S.SummonGargoyle:CooldownRemains() > 60) and (Pet:BuffUp(S.DarkTransformation) and S.Berserking:BaseDuration() >= Pet:BuffRemains(S.DarkTransformation) or VarArmyGhoulActive and VarArmyGhoulRemains <= S.Berserking:BaseDuration() or VarApocGhoulActive and VarApocGhoulRemains <= S.Berserking:BaseDuration() or Enemies10ySplashCount >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or FightRemains <= S.Berserking:BaseDuration()) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 6"; end
  end
  -- lights_judgment,if=buff.unholy_strength.up&(!talent.festermight|buff.festermight.remains<target.time_to_die|buff.unholy_strength.remains<target.time_to_die)
  if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff) and ((not S.Festermight:IsAvailable()) or Player:BuffRemains(S.FestermightBuff) < Target:TimeToDie() or Player:BuffRemains(S.UnholyStrengthBuff) < Target:TimeToDie())) then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 8"; end
  end
  -- ancestral_call,if=(15>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(buff.dark_transformation.up&15>=buff.dark_transformation.remains|pet.army_ghoul.active&pet.army_ghoul.remains<=15|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=15|active_enemies>=2&death_and_decay.ticking)|fight_remains<=15
  if S.AncestralCall:IsCastable() and ((15 >= ghoul:gargremains() and ghoul:gargactive()) or ((not S.SummonGargoyle:IsAvailable()) or S.SummonGargoyle:CooldownRemains() > 60) and (Pet:BuffUp(S.DarkTransformation) and 15 >= Pet:BuffRemains(S.DarkTransformation) or VarArmyGhoulActive and VarArmyGhoulRemains <= 15 or VarApocGhoulActive and VarApocGhoulRemains <= 15 or Enemies10ySplashCount >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or FightRemains <= 15) then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD) then return "ancestral_call main 10"; end
  end
  -- arcane_pulse,if=active_enemies>=2|(rune.deficit>=5&runic_power.deficit>=60)
  if S.ArcanePulse:IsCastable() and (EnemiesMeleeCount >= 2 or (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
    if Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse main 12"; end
  end
  -- fireblood,if=(buff.fireblood.duration>=pet.gargoyle.remains&pet.gargoyle.active)|(!talent.summon_gargoyle|cooldown.summon_gargoyle.remains>60)&(buff.dark_transformation.up&buff.fireblood.duration>=buff.dark_transformation.remains|pet.army_ghoul.active&pet.army_ghoul.remains<=buff.fireblood.duration|pet.apoc_ghoul.active&pet.apoc_ghoul.remains<=buff.fireblood.duration|active_enemies>=2&death_and_decay.ticking)|fight_remains<=buff.fireblood.duration
  if S.Fireblood:IsCastable() and ((S.Fireblood:BaseDuration() >= ghoul:gargremains() and ghoul:gargactive()) or ((not S.SummonGargoyle:IsAvailable()) or S.SummonGargoyle:CooldownRemains() > 60) and (Pet:BuffUp(S.DarkTransformation) and S.Fireblood:BaseDuration() >= Pet:BuffRemains(S.DarkTransformation) or VarArmyGhoulActive and VarArmyGhoulRemains <= S.Fireblood:BaseDuration() or VarApocGhoulActive and VarApocGhoulRemains <= S.Fireblood:BaseDuration() or Enemies10ySplashCount >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) or FightRemains <= S.Fireblood:BaseDuration()) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 14"; end
  end
  -- bag_of_tricks,if=active_enemies=1&(buff.unholy_strength.up|fight_remains<5)
  if S.BagofTricks:IsCastable() and (EnemiesMeleeCount == 1 and (Player:BuffUp(S.UnholyStrengthBuff) or HL.FilteredFightRemains(EnemiesMelee, "<", 5))) then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 16"; end
  end
end

local function Generic()
  -- death_coil,if=!variable.pooling_runic_power&(buff.sudden_doom.react|runic_power.deficit<=40|rune<3)|pet.gargoyle.active|fight_remains<(30%gcd)
  if S.DeathCoil:IsReady() and ((not VarPoolingRunicPower) and (Player:BuffUp(S.SuddenDoomBuff) or Player:RunicPowerDeficit() <= 40 or Player:Rune() < 3) or ghoul:gargactive() or FightRemains < (30 / Player:GCD())) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil generic 2"; end
  end
  -- any_dnd,if=active_enemies>=2&death_knight.fwounded_targets=active_enemies
  if AnyDnD:IsReady() and (Enemies10ySplashCount >= 2 and S.FesteringWoundDebuff:AuraActiveCount() == EnemiesMeleeCount) then
    if AnyDnD == S.DeathsDue then
      if Cast(AnyDnD, nil, Settings.Commons.DisplayStyle.Covenant) then return "any_dnd generic 4"; end
    else
      if Cast(AnyDnD, Settings.Commons.OffGCDasOffGCD.DeathAndDecay) then return "any_dnd generic 6"; end
    end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=variable.pop_wounds|active_enemies>=2&death_and_decay.ticking
  if WoundSpender:IsReady() and (VarPopWounds or EnemiesMeleeCount >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender generic 8"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack<4&cooldown.apocalypse.remains<variable.apoc_timing
  if S.FesteringStrike:IsReady() and (S.Apocalypse:CooldownRemains() < VarApocTiming) then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrike, not Target:IsInMeleeRange(5)) then return "festering_strike generic 10"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=variable.build_wounds
  if S.FesteringStrike:IsReady() and (VarBuildWounds) then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, nil, not Target:IsInMeleeRange(5)) then return "festering_strike generic 12"; end
  end
end

local function Trinkets()
  -- use_item,name=gavel_of_the_first_arbiter
  if I.GaveloftheFirstArbiter:IsEquippedAndReady() and Settings.Commons.Enabled.Items then
    if Cast(I.GaveloftheFirstArbiter, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(30)) then return "gavel_of_the_first_arbiter trinkets 2"; end
  end
  -- use_item,slot=trinket1,if=((trinket.1.proc.any_dps.duration<=15&cooldown.apocalypse.remains>20|trinket.1.proc.any_dps.duration>15&(cooldown.unholy_blight.remains>20|cooldown.dark_transformation.remains_expected>20)|active_enemies>=2&buff.dark_transformation.up)&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1))|trinket.1.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket2,if=((trinket.2.proc.any_dps.duration<=15&cooldown.apocalypse.remains>20|trinket.2.proc.any_dps.duration>15&(cooldown.unholy_blight.remains>20|cooldown.dark_transformation.remains_expected>20)|active_enemies>=2&buff.dark_transformation.up)&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2))|trinket.2.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket1,if=!trinket.1.has_use_buff&(trinket.2.cooldown.remains|!trinket.2.has_use_buff)
  -- use_item,slot=trinket2,if=!trinket.2.has_use_buff&(trinket.1.cooldown.remains|!trinket.1.has_use_buff)
  -- TODO: Add above lines and remove below lines when we can handle the trinket sync/priority variables. For now, keeping the old trinket setup below.
  -- use_items,if=(cooldown.apocalypse.remains|buff.dark_transformation.up)&(!equipped.inscrutable_quantum_device|cooldown.inscrutable_quantum_device.remains)
  if ((S.Apocalypse:CooldownDown() or Pet:BuffUp(S.DarkTransformation)) and (not I.InscrutableQuantumDevice:IsEquipped() or I.InscrutableQuantumDevice:CooldownRemains() > 0)) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  no_heal = not DeathStrikeHeal()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(8)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
    Enemies10ySplashCount = #Enemies10ySplash
  else
    EnemiesMeleeCount = 1
    Enemies10ySplashCount = 1
  end

  -- Check which enemies don't have Virulent Plague
  EnemiesWithoutVP = UnitsWithoutVP(Enemies10ySplash)

  -- Is Apocalypse Ghoul active?
  VarApocGhoulActive = S.Apocalypse:TimeSinceLastCast() <= 15
  VarApocGhoulRemains = (VarApocGhoulActive) and 15 - S.Apocalypse:TimeSinceLastCast() or 0
  VarArmyGhoulActive = S.ArmyoftheDead:TimeSinceLastCast() <= 30
  VarArmyGhoulRemains = (VarArmyGhoulRemains) and 30 - S.ArmyoftheDead:TimeSinceLastCast() or 0

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10yd, false)
    end
  end

  -- Set WoundSpender and AnyDnD
  WoundSpender = (S.ClawingShadows:IsAvailable() and S.ClawingShadows or S.ScourgeStrike)
  AnyDnD = S.DeathAndDecay
  if S.DeathsDue:IsAvailable() then AnyDnD = S.DeathsDue end
  if S.Defile:IsAvailable() then AnyDnD = S.Defile end

  if Everyone.TargetIsValid() then
    -- Check our stacks of Festering Wounds
    FesterStacks = Target:DebuffStack(S.FesteringWoundDebuff)
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- interrupts
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady() and not no_heal then
      if Cast(S.DeathStrike) then return "death_strike low hp or proc"; end
    end
    -- auto_attack
    -- variable,name=apoc_timing,op=setif,value=((rune.time_to_3)%((debuff.festering_wound.stack+1)%4))+gcd+(talent.unholy_assault*4),value_else=gcd*3,condition=cooldown.apocalypse.remains<7
    if S.Apocalypse:CooldownRemains() < 7 then
      VarApocTiming = ((Player:RuneTimeToX(3) / ((FesterStacks + 1) / 4)) + Player:GCD() + (num(S.UnholyAssault:IsAvailable()) * 4))
    else
      VarApocTiming = Player:GCD() * 3
    end
    -- variable,name=garg_pooling,op=setif,value=(((cooldown.summon_gargoyle.remains+1)%gcd)%((rune+1)*(runic_power+20)))*100,value_else=gcd*2,condition=runic_power.deficit>60&cooldown.summon_gargoyle.remains<7
    if Player:RunicPowerDeficit() > 60 and S.SummonGargoyle:CooldownRemains() < 7 then
      VarGargPooling = ((((S.SummonGargoyle:CooldownRemains() + 1) / Player:GCD()) / ((Player:Rune() + 1) * (Player:RunicPower() + 20))) * 100)
    else
      VarGargPooling = Player:GCD() * 2
    end
    -- variable,name=festermight_tracker,op=setif,value=debuff.festering_wound.stack>=1,value_else=debuff.festering_wound.stack>=4,condition=talent.festermight&(buff.festermight.remains%(4*gcd))>=1&cooldown.apocalypse.remains>variable.apoc_timing
    if (S.Festermight:IsAvailable() and (Player:BuffRemains(S.FestermightBuff) / (4 * Player:GCD())) >= 1 and S.Apocalypse:CooldownRemains() > VarApocTiming) then
      VarFesterTracker = FesterStacks >= 1
    else
      VarFesterTracker = FesterStacks >= 4
    end
    -- variable,name=build_wounds,value=debuff.festering_wound.stack<4
    VarBuildWounds = FesterStacks < 4
    -- variable,name=pop_wounds,value=!cooldown.apocalypse.ready&(variable.festermight_tracker|debuff.festering_wound.stack>=1&!talent.apocalypse|debuff.festering_wound.up&cooldown.unholy_assault.remains<30&talent.unholy_assault&variable.st_planning|debuff.festering_wound.stack>4)
    VarPopWounds = (S.Apocalypse:CooldownDown() and (VarFesterTracker or FesterStacks >= 1 and (not S.Apocalypse:IsAvailable()) or FesterStacks > 0 and S.UnholyAssault:CooldownRemains() < 30 and S.UnholyAssault:IsAvailable() and VarSTPlanning or FesterStacks > 4))
    -- variable,name=pooling_runic_power,value=cooldown.summon_gargoyle.remains<variable.garg_pooling&talent.summon_gargoyle|talent.eternal_agony&cooldown.dark_transformation.remains<3&!active_enemies>=3|talent.vile_contagion&cooldown.vile_contagion.remains<3&runic_power<60&!variable.st_planning
    VarPoolingRunicPower = (S.SummonGargoyle:CooldownRemains() < VarGargPooling and S.SummonGargoyle:IsAvailable() or S.EternalAgony:IsAvailable() and S.DarkTransformation:CooldownRemains() < 3 and Enemies10ySplashCount < 3 or S.VileContagion:IsAvailable() and S.VileContagion:CooldownRemains() < 3 and Player:RunicPower() < 60 and not VarSTPlanning)
    -- variable,name=pooling_runes,value=talent.soul_reaper&rune<2&target.time_to_pct_35<5&fight_remains>(dot.soul_reaper.remains+5)|talent.eternal_agony&talent.ghoulish_frenzy&cooldown.dark_transformation.remains<4
    VarPoolingRunes = (S.SoulReaper:IsAvailable() and Player:Rune() < 2 and Target:TimeToX(35) < 5 and FightRemains > (Target:DebuffRemains(S.SoulReaper) + 5) or S.EternalAgony:IsAvailable() and S.GhoulishFrenzy:IsAvailable() and S.DarkTransformation:CooldownRemains() < 4)
    -- variable,name=st_planning,value=active_enemies<=3&(!raid_event.adds.exists|raid_event.adds.in>15)
    VarSTPlanning = (EnemiesMeleeCount <= 3 or not AoEON())
    -- variable,name=adds_remain,value=active_enemies>=4&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>6)
    VarAddsRemain = (EnemiesMeleeCount >= 4 and AoEON())
    -- Manually added: Outbreak if targets are missing VP and out of range
    if S.Outbreak:IsReady() and (EnemiesWithoutVP > 0 and EnemiesMeleeCount == 0) then
      if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak out_of_range"; end
    end
    -- Manually added: epidemic,if=!variable.pooling_runic_power&active_enemies=0
    if S.Epidemic:IsReady() and AoEON() and S.VirulentPlagueDebuff:AuraActiveCount() > 1 and (not VarPoolingRunicPower and EnemiesMeleeCount == 0) then
      if Cast(S.Epidemic, nil, nil, not Target:IsInRange(30)) then return "epidemic out_of_range"; end
    end
    -- Manually added: death_coil,if=!variable.pooling_runic_power&active_enemies=0
    if S.DeathCoil:IsReady() and S.VirulentPlagueDebuff:AuraActiveCount() < 2 and (not VarPoolingRunicPower and EnemiesMeleeCount == 0) then
      if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil out_of_range"; end
    end
    -- wait_for_cooldown,name=soul_reaper,if=talent.soul_reaper&target.time_to_pct_35<5&fight_remains>5&cooldown.soul_reaper.remains<(gcd*0.75)&active_enemies=1
    if (S.SoulReaper:IsAvailable() and Target:TimeToX(35) < 5 and FightRemains > 5 and S.SoulReaper:CooldownRemains() < (Player:GCD() * 0.75) and S.SoulReaper:CooldownDown() and Enemies10ySplashCount == 1) then
      if HR.CastAnnotated(S.Pool, false, "WAIT/SR") then return "Wait for Soul Reaper"; end
    end
    -- outbreak,target_if=(dot.virulent_plague.refreshable|dot.frost_fever_superstrain.refreshable|dot.blood_plague_superstrain.refreshable)&(!talent.unholy_blight|talent.unholy_blight&cooldown.unholy_blight.remains>15%((talent.superstrain*3)+(talent.plaguebringer*2)))
    if S.Outbreak:IsReady() and ((Target:DebuffRefreshable(S.VirulentPlagueDebuff) or (S.Superstrain:IsAvailable() and (Target:DebuffRefreshable(S.FrostFeverDebuff) or Target:DebuffRefreshable(S.BloodPlagueDebuff)))) and ((not S.UnholyBlight:IsAvailable()) or S.UnholyBlight:IsAvailable() and S.UnholyBlight:CooldownRemains() > 15 / ((num(S.Superstrain:IsAvailable()) * 3) + (num(S.Plaguebringer:IsAvailable()) * 2)))) then
      if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak main 2"; end
    end
    -- wound_spender,if=cooldown.apocalypse.remains>variable.apoc_timing&talent.plaguebringer&talent.superstrain&buff.plaguebringer.remains<gcd
    if WoundSpender:IsReady() and (S.Apocalypse:CooldownRemains() > VarApocTiming and S.Plaguebringer:IsAvailable() and S.Superstrain:IsAvailable() and Player:BuffRemains(S.PlaguebringerBuff) < Player:GCD()) then
      if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender main 4"; end
    end
    -- call_action_list,name=trinkets
    if (Settings.Commons.Enabled.Trinkets) then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials
    if (CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- sequence,if=active_enemies=1&!death_knight.disable_aotd&talent.summon_gargoyle,name=garg_opener:outbreak:festering_strike:festering_strike:summon_gargoyle:army_of_the_dead:death_coil,if=buff.sudden_doom.up:death_coil:death_coil:scourge_strike,if=debuff.festering_wound.stack>4:scourge_strike,if=debuff.festering_wound.stack>4:festering_strike
    -- sequence,if=active_enemies=1&!death_knight.disable_aotd&!talent.summon_gargoyle,name=opener:festering_strike:festering_strike:potion:unholy_blight:dark_transformation:apocalypse
    -- TODO: Add handle above openers
    -- call_action_list,name=cooldowns
    if (CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=covenants
    if (true) then
      local ShouldReturn = Covenants(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=aoe,if=active_enemies>=4
    if (AoEON() and Enemies10ySplashCount >= 4) then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
      if Cast(S.Pool) then return "pool for AoE()"; end
    end
    -- run_action_list,name=generic,if=active_enemies<=3
    if (Enemies10ySplashCount <= 3) then
      local ShouldReturn = Generic(); if ShouldReturn then return ShouldReturn; end
      if Cast(S.Pool) then return "pool for Generic()"; end
    end
    -- Add pool resources icon if nothing else to do
    if (true) then
      if Cast(S.Pool) then return "pool_resources"; end
    end
  end
end

local function Init()
  S.VirulentPlagueDebuff:RegisterAuraTracking()
  S.FesteringWoundDebuff:RegisterAuraTracking()

  HR.Print("Unholy DK rotation is currently a work in progress, but has been updated for patch 10.0.0.")
end

HR.SetAPL(252, APL, Init)
