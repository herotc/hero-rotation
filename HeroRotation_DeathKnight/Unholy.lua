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
  I.DarkmoonDeckVoracity:ID(),
  I.DreadfireVessel:ID(),
  I.InscrutableQuantumDevice:ID(),
  I.MacabreSheetMusic:ID(),
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
local VarPoolingRunicPower
local VarPoolingRunes
local VarSTPlanning
local VarMajorCDsActive
local VarGargoyleActive
local VarApocGhoulActive
local WoundSpender
local AnyDnD
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority
local VarSpecifiedTrinket

-- Enemies Variables
local EnemiesMelee, EnemiesMeleeCount
local Enemies10ySplash, Enemies10ySplashCount
local EnemiesWithoutVP

-- Legendaries
local SuperstrainEquipped = Player:HasLegendaryEquipped(30)
local PhearomonesEquipped = Player:HasLegendaryEquipped(31)
local DeadliestCoilEquipped = Player:HasLegendaryEquipped(45)

-- Stun Interrupts List
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

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
  SuperstrainEquipped = Player:HasLegendaryEquipped(30)
  PhearomonesEquipped = Player:HasLegendaryEquipped(31)
  DeadliestCoilEquipped = Player:HasLegendaryEquipped(45)
end, "PLAYER_EQUIPMENT_CHANGED")

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
  return (EnemiesMeleeCount >= 2 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4 and Player:BuffDown(S.DeathAndDecayBuff))
end

local function EvaluateTargetIfFesteringStrike(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 3 and S.Apocalypse:CooldownRemains() < 3)
end

local function EvaluateTargetIfFesteringStrike2(TargetUnit)
  return (Player:RuneTimeToX(4) < AnyDnD:CooldownRemains())
end

local function EvaluateTargetIfFesteringStrike3(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 3 and S.Apocalypse:CooldownRemains() < 3 or TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 1)
end

local function EvaluateTargetIfFesteringStrike4(TargetUnit)
  return (S.Apocalypse:CooldownRemains() > 5 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 1)
end

local function EvaluateTargetIfUnholyAssault(TargetUnit)
  return (EnemiesMeleeCount >= 2 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 2)
end

local function EvaluateTargetIfWoundSpender(TargetUnit)
  return ((S.Apocalypse:CooldownRemains() > 5 and TargetUnit:DebuffUp(S.FesteringWoundDebuff) or TargetUnit:DebuffStack(S.FesteringWoundDebuff) > 4) and (HL.FilteredFightRemains(EnemiesMelee, "<", AnyDnD:CooldownRemains() + 10) or HL.FilteredFightRemains(EnemiesMelee, ">", S.Apocalypse:CooldownRemains())))
end

local function EvaluateCycleFesteringStrike(TargetUnit)
  return (TargetUnit:DebuffDown(S.FesteringWoundDebuff))
end

local function EvaluateCycleSoulReaper(TargetUnit)
  return ((TargetUnit:TimeToX(35) < 5 or TargetUnit:HealthPercentage() < 35) and TargetUnit:TimeToDie() > 5)
end

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
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(trinket.1.cooldown.duration%%45=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(trinket.2.cooldown.duration%%45=0)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!trinket.1.has_use_buff&trinket.2.has_use_buff|trinket.2.has_use_buff&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- TODO: Trinket sync/priority stuff. Currently unable to pull trinket CD durations because WoW's API is bad.
  -- Manually added: army_of_the_dead
  if S.ArmyoftheDead:IsReady() then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyoftheDead) then return "army_of_the_dead precombat 4"; end
  end
  -- Manually added: festering_strike if in melee range
  if S.FesteringStrike:IsReady() and Target:IsSpellInRange(S.FesteringStrike) then
    if Cast(S.FesteringStrike) then return "festering_strike precombat 6"; end
  end
  -- Manually added: outbreak if not in melee range
  if S.Outbreak:IsReady() then
    if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak precombat 8"; end
  end
end

local function AOE_Setup()
  -- any_dnd,if=death_knight.fwounded_targets=active_enemies|raid_event.adds.exists&raid_event.adds.remains<=11
  -- any_dnd,if=death_knight.fwounded_targets>=5
  if AnyDnD:IsReady() and (S.FesteringWoundDebuff:AuraActiveCount() == EnemiesMeleeCount or S.FesteringWoundDebuff:AuraActiveCount() >= 5 or Enemies10ySplashCount > 1 and AddsFightRemains(Enemies10ySplash) <= 11) then
    if AnyDnD == S.DeathsDue then
      if Cast(AnyDnD, nil, Settings.Commons.DisplayStyle.Covenant) then return "any_dnd aoe_setup 2"; end
    else
      if Cast(AnyDnD, Settings.Commons.OffGCDasOffGCD.DeathAndDecay) then return "any_dnd aoe_setup 4"; end
    end
  end
  -- death_coil,if=!variable.pooling_runic_power&(buff.dark_transformation.up&runeforge.deadliest_coil&active_enemies<=3|active_enemies=2)
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower and (Pet:BuffUp(S.DarkTransformation) and DeadliestCoilEquipped and EnemiesMeleeCount <= 3 or EnemiesMeleeCount == 2)) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil aoe_setup 10"; end
  end
  -- epidemic,if=!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(30)) then return "epidemic aoe_setup 12"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack<=3&cooldown.apocalypse.remains<3
  if S.FesteringStrike:IsReady() then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrike) then return "festering_strike aoe_setup 14"; end
  end
  -- festering_strike,target_if=debuff.festering_wound.stack<1
  if S.FesteringStrike:IsReady() then
    if Everyone.CastCycle(S.FesteringStrike, EnemiesMelee, EvaluateCycleFesteringStrike) then return "festering_strike aoe_setup 16"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=rune.time_to_4<(cooldown.death_and_decay.remains&!talent.defile|cooldown.defile.remains&talent.defile)
  if S.FesteringStrike:IsReady() then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrike2) then return "festering_strike aoe_setup 16"; end
  end
end

local function AOE_Burst()
  -- death_coil,if=(buff.sudden_doom.react|!variable.pooling_runic_power)&(buff.dark_transformation.up&runeforge.deadliest_coil&active_enemies<=3|active_enemies=2)
  if S.DeathCoil:IsReady() and ((Player:BuffUp(S.SuddenDoomBuff) or not VarPoolingRunicPower) and (Pet:BuffUp(S.DarkTransformation) and DeadliestCoilEquipped and EnemiesMeleeCount <= 3 or EnemiesMeleeCount == 2)) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil aoe_burst 2"; end
  end
  -- epidemic,if=runic_power.deficit<(10+death_knight.fwounded_targets*3)&death_knight.fwounded_targets<6&!variable.pooling_runic_power|buff.swarming_mist.up
  if S.Epidemic:IsReady() and (Player:RunicPowerDeficit() < (10 + S.FesteringWoundDebuff:AuraActiveCount() * 3) and S.FesteringWoundDebuff:AuraActiveCount() < 6 and not VarPoolingRunicPower or Player:BuffUp(S.SwarmingMistBuff)) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(30)) then return "epidemic aoe_burst 4"; end
  end
  -- epidemic,if=runic_power.deficit<25&death_knight.fwounded_targets>5&!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (Player:RunicPowerDeficit() < 25 and S.FesteringWoundDebuff:AuraActiveCount() > 5 and not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(30)) then return "epidemic aoe_burst 6"; end
  end
  -- epidemic,if=!death_knight.fwounded_targets&!variable.pooling_runic_power|fight_remains<5|raid_event.adds.exists&raid_event.adds.remains<5
  if S.Epidemic:IsReady() and (S.FesteringWoundDebuff:AuraActiveCount() == 0 and not VarPoolingRunicPower or Enemies10ySplashCount > 1 and AddsFightRemains(Enemies10ySplash) < 5) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(30)) then return "epidemic aoe_burst 8"; end
  end
  -- wound_spender
  if WoundSpender:IsReady() then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender aoe_burst 10"; end
  end
  -- epidemic,if=!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(30)) then return "epidemic aoe_burst 12"; end
  end
end

local function AOE_Generic()
  -- wait_for_cooldown,name=soul_reaper,if=talent.soul_reaper&target.time_to_pct_35<5&fight_remains>5&cooldown.soul_reaper.remains<(gcd*0.75)&active_enemies<=3
  -- TODO: Potentially add this wait_for_cooldown
  -- death_coil,if=(!variable.pooling_runic_power|buff.sudden_doom.react)&(buff.dark_transformation.up&runeforge.deadliest_coil&active_enemies<=3|active_enemies=2)
  if S.DeathCoil:IsReady() and ((not VarPoolingRunicPower or Player:BuffUp(S.SuddenDoomBuff)) and (Pet:BuffUp(S.DarkTransformation) and DeadliestCoilEquipped and EnemiesMeleeCount <= 3 or EnemiesMeleeCount == 2)) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil aoe_generic 2"; end
  end
  -- epidemic,if=buff.sudden_doom.react|!variable.pooling_runic_power
  if S.Epidemic:IsReady() and (Player:BuffUp(S.SuddenDoomBuff) or not VarPoolingRunicPower) then
    if Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not Target:IsInRange(30)) then return "epidemic aoe_generic 4"; end
  end
  -- wound_spender,target_if=max:debuff.festering_wound.stack,if=(cooldown.apocalypse.remains>5&debuff.festering_wound.up|debuff.festering_wound.stack>4)&(fight_remains<cooldown.death_and_decay.remains+10|fight_remains>cooldown.apocalypse.remains)
  if WoundSpender:IsReady() then
    if Everyone.CastTargetIf(WoundSpender, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfWoundSpender) then return "wound_spender aoe_generic 6"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack<=3&cooldown.apocalypse.remains<3|debuff.festering_wound.stack<1
  if S.FesteringStrike:IsReady() then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrike3) then return "festering_strike aoe_generic 8"; end
  end
  -- festering_strike,target_if=min:debuff.festering_wound.stack,if=cooldown.apocalypse.remains>5&debuff.festering_wound.stack<1
  if S.FesteringStrike:IsReady() then
    if Everyone.CastTargetIf(S.FesteringStrike, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfFesteringStrike4) then return "festering_strike aoe_generic 10"; end
  end
end

local function Cooldowns()
  -- potion,if=variable.major_cooldowns_active|fight_remains<26
  if I.PotionofSpectralStrength:IsReady() and Settings.Commons.Enabled.Potions and (VarMajorCDsActive or HL.FilteredFightRemains(EnemiesMelee, "<", 26)) then
    if Cast(I.PotionofSpectralStrength, Settings.Commons.OffGCDasOffGCD.Potions) then return "potion cooldowns 2"; end
  end
  -- army_of_the_dead,if=cooldown.unholy_blight.remains<5&cooldown.dark_transformation.remains_expected<5&talent.unholy_blight|!talent.unholy_blight|fight_remains<35
  if S.ArmyoftheDead:IsReady() and (S.UnholyBlight:CooldownRemains() < 5 and S.DarkTransformation:CooldownRemains() < 5 and S.UnholyBlight:IsAvailable() or not S.UnholyBlight:IsAvailable() or HL.FilteredFightRemains(EnemiesMelee, "<", 35)) then
    if Cast(S.ArmyoftheDead, nil, Settings.Unholy.DisplayStyle.ArmyoftheDead) then return "army_of_the_dead cooldowns 4"; end
  end
  -- soul_reaper,target_if=target.time_to_pct_35<5&target.time_to_die>5&active_enemies<=3
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount <= 3) then
    if ((Target:TimeToX(35) < 5 or Target:HealthPercentage() < 35) and Target:TimeToDie() > 5) then
      if Cast(S.SoulReaper, nil, nil, not Target:IsSpellInRange(S.SoulReaper)) then return "soul_reaper cooldowns 5"; end
    else
      if Everyone.CastCycle(S.SoulReaper, EnemiesMelee, EvaluateCycleSoulReaper) then return "soul_reaper cooldowns 6"; end
    end
  end
  -- unholy_blight,if=variable.st_planning&(cooldown.apocalypse.remains_expected<5|cooldown.apocalypse.remains_expected>10)&(cooldown.dark_transformation.remains<gcd|buff.dark_transformation.up)
  if S.UnholyBlight:IsReady() and (VarSTPlanning and (S.Apocalypse:CooldownRemains() < 5 or S.Apocalypse:CooldownRemains() > 10) and (S.DarkTransformation:CooldownRemains() < Player:GCD() or Pet:BuffUp(S.DarkTransformation))) then
    if Cast(S.UnholyBlight, nil, nil, not Target:IsInRange(8)) then return "unholy_blight cooldowns 8"; end
  end
  -- unholy_blight,if=active_enemies>=2|fight_remains<21
  if S.UnholyBlight:IsReady() and (EnemiesMeleeCount >= 2 or HL.FilteredFightRemains(EnemiesMelee, "<", 21)) then
    if Cast(S.UnholyBlight, nil, nil, not Target:IsInRange(8)) then return "unholy_blight cooldowns 10"; end
  end
  -- dark_transformation,if=variable.st_planning&(dot.unholy_blight_dot.remains|!talent.unholy_blight)
  if S.DarkTransformation:IsCastable() and (VarSTPlanning and (Target:DebuffUp(S.UnholyBlightDebuff) or not S.UnholyBlight:IsAvailable())) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cooldowns 12"; end
  end
  -- dark_transformation,if=active_enemies>=2|fight_remains<21
  if S.DarkTransformation:IsCastable() and (EnemiesMeleeCount >= 2 or HL.FilteredFightRemains(EnemiesMelee, "<", 21)) then
    if Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation cooldowns 14"; end
  end
  -- apocalypse,if=active_enemies=1&debuff.festering_wound.stack>=4
  if S.Apocalypse:IsCastable() and S.Apocalypse:IsUsable() and ((EnemiesMeleeCount == 1 or not AoEON()) and Target:DebuffStack(S.FesteringWoundDebuff) >= 4) then
    if Cast(S.Apocalypse, Settings.Unholy.GCDasOffGCD.Apocalypse, nil, not Target:IsSpellInRange(S.Apocalypse)) then return "apocalypse cooldowns 16"; end
  end
  -- apocalypse,target_if=max:debuff.festering_wound.stack,if=active_enemies>=2&debuff.festering_wound.stack>=4&!death_and_decay.ticking
  if S.Apocalypse:IsCastable() and S.Apocalypse:IsUsable() then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "max", EvaluateTargetIfFilterFWStack, EvaluateTargetIfApocalypse, not Target:IsSpellInRange(S.Apocalypse), Settings.Unholy.GCDasOffGCD.Apocalypse) then return "apocalypse cooldowns 18"; end
  end
  -- summon_gargoyle,if=runic_power.deficit<14&(cooldown.unholy_blight.remains<10|dot.unholy_blight_dot.remains)
  if S.SummonGargoyle:IsCastable() and (Player:RunicPowerDeficit() < 14 and (S.UnholyBlight:CooldownRemains() < 10 or Target:DebuffUp(S.UnholyBlightDebuff))) then
    if Cast(S.SummonGargoyle, Settings.Unholy.GCDasOffGCD.SummonGargoyle, nil, not Target:IsInRange(30)) then return "summon_gargoyle cooldowns 20"; end
  end
  -- unholy_assault,if=variable.st_planning&debuff.festering_wound.stack<2&(pet.apoc_ghoul.active|buff.dark_transformation.up&!pet.army_ghoul.active)
  if S.UnholyAssault:IsCastable() and (VarSTPlanning and Target:DebuffStack(S.FesteringWoundDebuff) < 2 and (VarApocGhoulActive or Pet:BuffUp(S.DarkTransformation) and S.ArmyoftheDead:TimeSinceLastCast() > 30)) then
    if Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault) then return "unholy_assault cooldowns 22"; end
  end
  -- unholy_assault,target_if=min:debuff.festering_wound.stack,if=active_enemies>=2&debuff.festering_wound.stack<2
  if S.UnholyAssault:IsCastable() then
    if Everyone.CastTargetIf(S.UnholyAssault, EnemiesMelee, "min", EvaluateTargetIfFilterFWStack, EvaluateTargetIfUnholyAssault) then return "unholy_assault cooldowns 24"; end
  end
  -- raise_dead,if=!pet.ghoul.active
  if S.RaiseDead:IsCastable() then
    if Settings.Unholy.RaiseDeadCastLeft then
      if HR.CastLeft(S.RaiseDead) then return "raise_dead cooldowns 26 left"; end
    else
      if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead cooldowns 26 displaystyle"; end
    end
  end
  -- sacrificial_pact,if=active_enemies>=2&!buff.dark_transformation.up&!cooldown.dark_transformation.ready|fight_remains<gcd
  if S.SacrificialPact:IsReady() and (EnemiesMeleeCount >= 2 and Pet:BuffDown(S.DarkTransformation) and not S.DarkTransformation:CooldownUp() or HL.FilteredFightRemains(EnemiesMelee, "<", Player:GCD())) then
    if Cast(S.SacrificialPact, Settings.Commons.OffGCDasOffGCD.SacrificialPact, nil, not Target:IsInRange(8)) then return "sacrificial_pact cooldowns 28"; end
  end
end

local function Covenants()
  -- swarming_mist,if=variable.st_planning&runic_power.deficit>16&(cooldown.apocalypse.remains|!talent.army_of_the_damned&cooldown.dark_transformation.remains)|fight_remains<11
  if S.SwarmingMist:IsReady() and (VarSTPlanning and Player:RunicPowerDeficit() > 16 and (not S.Apocalypse:CooldownUp() or not S.ArmyoftheDamned:IsAvailable() and not S.DarkTransformation:CooldownUp()) or HL.FilteredFightRemains(EnemiesMelee, "<", 11)) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(10)) then return "swarming_mist covenants 2"; end
  end
  -- swarming_mist,if=cooldown.apocalypse.remains&(active_enemies>=2&active_enemies<=5&runic_power.deficit>10+(active_enemies*6)|active_enemies>5&runic_power.deficit>40)
  if S.SwarmingMist:IsReady() and (not S.Apocalypse:CooldownUp() and (EnemiesMeleeCount >= 2 and EnemiesMeleeCount <= 5 and Player:RunicPowerDeficit() > 10 + (EnemiesMeleeCount * 6) or EnemiesMeleeCount > 5 and Player:RunicPowerDeficit() > 40)) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(10)) then return "swarming_mist covenants 4"; end
  end
  -- abomination_limb,if=variable.st_planning&!soulbind.lead_by_example&(cooldown.apocalypse.remains|!talent.army_of_the_damned&cooldown.dark_transformation.remains)&rune.time_to_4>(3+buff.runic_corruption.remains)|fight_remains<21
  if S.AbominationLimb:IsCastable() and (VarSTPlanning and not S.LeadByExample:SoulbindEnabled() and (not S.Apocalypse:CooldownUp() or not S.ArmyoftheDamned:IsAvailable() and not S.DarkTransformation:CooldownUp()) and Player:RuneTimeToX(4) > (3 + Player:BuffRemains(S.RunicCorruptionBuff)) or HL.FilteredFightRemains(EnemiesMelee, "<", 21)) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant) then return "abomination_limb covenants 6"; end
  end
  -- abomination_limb,if=variable.st_planning&soulbind.lead_by_example&(dot.unholy_blight_dot.remains>11|!talent.unholy_blight&cooldown.dark_transformation.remains)
  if S.AbominationLimb:IsCastable() and (VarSTPlanning and S.LeadByExample:SoulbindEnabled() and (Target:DebuffRemains(S.UnholyBlightDebuff) > 11 or not S.UnholyBlight:IsAvailable() and not S.DarkTransformation:CooldownUp())) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant) then return "abomination_limb covenants 8"; end
  end
  -- abomination_limb,if=active_enemies>=2&rune.time_to_4>(3+buff.runic_corruption.remains)
  if S.AbominationLimb:IsCastable() and (EnemiesMeleeCount >= 2 and Player:RuneTimeToX(4) > (3 + Player:BuffRemains(S.RunicCorruptionBuff))) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant) then return "abomination_limb covenants 10"; end
  end
  -- shackle_the_unworthy,if=variable.st_planning&(cooldown.apocalypse.remains|!talent.army_of_the_damned&cooldown.dark_transformation.remains)|fight_remains<15
  if S.ShackleTheUnworthy:IsCastable() and (VarSTPlanning and (not S.Apocalypse:CooldownUp() or not S.ArmyoftheDamned:CooldownUp() and not S.DarkTransformation:CooldownUp()) or HL.FilteredFightRemains(EnemiesMelee, "<", 15)) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ShackleTheUnworthy)) then return "shackle_the_unworthy covenants 12"; end
  end
  -- shackle_the_unworthy,if=active_enemies>=2&(death_and_decay.ticking|raid_event.adds.remains<=14)
  if S.ShackleTheUnworthy:IsCastable() and (EnemiesMeleeCount >= 2 and (Player:BuffUp(S.DeathAndDecayBuff) or Enemies10ySplashCount > 1 and AddsFightRemains(Enemies10ySplashCount) <= 14)) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ShackleTheUnworthy)) then return "shackle_the_unworthy covenants 14"; end
  end
end

local function Racials()
  -- arcane_torrent,if=runic_power.deficit>65&(pet.gargoyle.active|!talent.summon_gargoyle.enabled)&rune.deficit>=5
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 65 and (VarGargoyleActive or not S.SummonGargoyle:IsAvailable()) and Player:Rune() <= 1) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 2"; end
  end
  -- blood_fury,if=variable.major_cooldowns_active|target.time_to_die<=buff.blood_fury.duration
  if S.BloodFury:IsCastable() and (VarMajorCDsActive or Target:TimeToDie() <= S.BloodFury:BaseDuration()) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 4"; end
  end
  -- berserking,if=variable.major_cooldowns_active|target.time_to_die<=buff.berserking.duration
  if S.Berserking:IsCastable() and (VarMajorCDsActive or Target:TimeToDie() <= S.Berserking:BaseDuration()) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 6"; end
  end
  -- lights_judgment,if=buff.unholy_strength.up
  if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff)) then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 8"; end
  end
  -- ancestral_call,if=variable.major_cooldowns_active|target.time_to_die<=15
  if S.AncestralCall:IsCastable() and (VarMajorCDsActive or Target:TimeToDie() <= 15) then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD) then return "ancestral_call main 10"; end
  end
  -- arcane_pulse,if=active_enemies>=2|(rune.deficit>=5&runic_power.deficit>=60)
  if S.ArcanePulse:IsCastable() and (EnemiesMeleeCount >= 2 or (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
    if Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse main 12"; end
  end
  -- fireblood,if=variable.major_cooldowns_active|target.time_to_die<=buff.fireblood.duration
  if S.Fireblood:IsCastable() and (VarMajorCDsActive or Target:TimeToDie() <= S.Fireblood:BaseDuration()) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 14"; end
  end
  -- bag_of_tricks,if=buff.unholy_strength.up&active_enemies=1
  if S.BagofTricks:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff) and (EnemiesMeleeCount == 1 or not AoEON())) then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 16"; end
  end
end

local function Generic()
  -- death_coil,if=buff.sudden_doom.react&!variable.pooling_runic_power|pet.gargoyle.active
  if S.DeathCoil:IsReady() and (Player:BuffUp(S.SuddenDoomBuff) and not VarPoolingRunicPower or VarGargoyleActive) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil generic 2"; end
  end
  -- death_coil,if=covenant.night_fae&cooldown.deaths_due.remains<3&runic_power.deficit<10
  if S.DeathCoil:IsReady() and (Player:Covenant() == "Night Fae" and S.DeathsDue:CooldownRemains() < 3 and Player:RunicPowerDeficit() < 10) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil generic 4"; end
  end
  -- any_dnd,if=(talent.defile.enabled|covenant.night_fae|runeforge.phearomones)&(!variable.pooling_runes|fight_remains<5)
  if AnyDnD:IsReady() and ((S.Defile:IsAvailable() or Player:Covenant() == "Night Fae" or PhearomonesEquipped) and (not VarPoolingRunes or HL.FilteredFightRemains(EnemiesMelee, "<", 5))) then
    if AnyDnD == S.DeathsDue then
      if Cast(AnyDnD, nil, Settings.Commons.DisplayStyle.Covenant) then return "any_dnd generic 6"; end
    else
      if Cast(AnyDnD, Settings.Commons.OffGCDasOffGCD.DeathAndDecay) then return "any_dnd generic 8"; end
    end
  end
  -- death_coil,if=covenant.night_fae&runic_power.deficit<20&!variable.pooling_runic_power
  if S.DeathCoil:IsReady() and (Player:Covenant() == "Night Fae" and Player:RunicPowerDeficit() < 20 and not VarPoolingRunicPower) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil generic 10"; end
  end
  -- festering_strike,if=covenant.night_fae&cooldown.deaths_due.remains<10&debuff.festering_wound.stack<4&!variable.pooling_runes&(!death_and_decay.ticking|buff.deaths_due.stack=4)
  if S.FesteringStrike:IsReady() and (Player:Covenant() == "Night Fae" and S.DeathsDue:CooldownRemains() < 10 and Target:DebuffStack(S.FesteringWoundDebuff) < 4 and not VarPoolingRunes and (Player:BuffDown(S.DeathAndDecayBuff) or Player:BuffStack(S.DeathsDue) == 4)) then
    if Cast(S.FesteringStrike, nil, nil, not Target:IsSpellInRange(S.FesteringStrike)) then return "festering_strike generic 12"; end
  end
  -- death_coil,if=runic_power.deficit<13|fight_remains<5&!debuff.festering_wound.up
  if S.DeathCoil:IsReady() and (Player:RunicPowerDeficit() < 13 or HL.FilteredFightRemains(EnemiesMelee, "<", 5) and Target:DebuffDown(S.FesteringWoundDebuff)) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil generic 14"; end
  end
  -- wound_spender,if=debuff.festering_wound.stack>4&!variable.pooling_runes
  if WoundSpender:IsReady() and (Target:DebuffStack(S.FesteringWoundDebuff) > 4 and not VarPoolingRunes) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender generic 16"; end
  end
  -- wound_spender,if=debuff.festering_wound.up&cooldown.apocalypse.remains_expected>5&!variable.pooling_runes
  if WoundSpender:IsReady() and (Target:DebuffUp(S.FesteringWoundDebuff) and S.Apocalypse:CooldownRemains() > 5 and not VarPoolingRunes) then
    if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender generic 18"; end
  end
  -- death_coil,if=runic_power.deficit<20&!variable.pooling_runic_power
  if S.DeathCoil:IsReady() and (Player:RunicPowerDeficit() < 20 and not VarPoolingRunicPower) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil generic 20"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<1&!variable.pooling_runes
  if S.FesteringStrike:IsReady() and (Target:DebuffDown(S.FesteringWoundDebuff) and not VarPoolingRunes) then
    if Cast(S.FesteringStrike, nil, nil, not Target:IsSpellInRange(S.FesteringStrike)) then return "festering_strike generic 22"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<4&cooldown.apocalypse.remains_expected<5&!variable.pooling_runes
  if S.FesteringStrike:IsReady() and (Target:DebuffStack(S.FesteringWoundDebuff) < 4 and S.Apocalypse:CooldownRemains() < 5 and not VarPoolingRunes) then
    if Cast(S.FesteringStrike, nil, nil, not Target:IsSpellInRange(S.FesteringStrike)) then return "festering_strike generic 24"; end
  end
  -- death_coil,if=!variable.pooling_runic_power
  if S.DeathCoil:IsReady() and (not VarPoolingRunicPower) then
    if Cast(S.DeathCoil, nil, nil, not Target:IsSpellInRange(S.DeathCoil)) then return "death_coil generic 26"; end
  end
end

local function Trinkets()
  -- use_item,name=inscrutable_quantum_device,if=(cooldown.unholy_blight.remains|cooldown.dark_transformation.remains)&(pet.army_ghoul.active|pet.apoc_ghoul.active&!talent.army_of_the_damned|target.time_to_pct_20<5)|fight_remains<21
  if I.InscrutableQuantumDevice:IsEquippedAndReady() and ((not S.UnholyBlight:CooldownUp() or not S.DarkTransformation:CooldownUp()) and (S.ArmyoftheDead:TimeSinceLastCast() <= 30 or VarApocGhoulActive and not S.ArmyoftheDamned:IsAvailable() or Target:TimeToX(20) < 5) or HL.FilteredFightRemains(EnemiesMelee, "<", 21)) then
    if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device trinkets 2"; end
  end
  -- use_item,slot=trinket1,if=!variable.specified_trinket&((trinket.1.proc.any_dps.duration<=15&cooldown.apocalypse.remains>20|trinket.1.proc.any_dps.duration>15&(cooldown.unholy_blight.remains>20|cooldown.dark_transformation.remains>20))&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1))|trinket.1.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket2,if=!variable.specified_trinket&((trinket.2.proc.any_dps.duration<=15&cooldown.apocalypse.remains>20|trinket.2.proc.any_dps.duration>15&(cooldown.unholy_blight.remains>20|cooldown.dark_transformation.remains>20))&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2))|trinket.2.proc.any_dps.duration>=fight_remains
  -- use_item,slot=trinket1,if=!trinket.1.has_use_buff&(trinket.2.cooldown.remains|!trinket.2.has_use_buff)
  -- use_item,slot=trinket2,if=!trinket.2.has_use_buff&(trinket.1.cooldown.remains|!trinket.1.has_use_buff)
  -- TODO: Add above lines and remove below lines when we can handle the trinket sync/priority variables. For now, keeping the old trinket setup below.
  -- use_item,name=macabre_sheet_music,if=cooldown.apocalypse.remains<5&(!equipped.inscrutable_quantum_device|cooldown.inscrutable_quantum_device.remains)|fight_remains<21
  if I.MacabreSheetMusic:IsEquippedAndReady() and (S.Apocalypse:CooldownRemains() < 5 and (not I.InscrutableQuantumDevice:IsEquipped() or I.InscrutableQuantumDevice:CooldownRemains() > 0) or HL.FilteredFightRemains(EnemiesMelee, "<", 21)) then
    if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music trinkets 4"; end
  end
  -- use_item,name=dreadfire_vessel,if=cooldown.apocalypse.remains&(!equipped.inscrutable_quantum_device|cooldown.inscrutable_quantum_device.remains)|fight_remains<3
  if I.DreadfireVessel:IsEquippedAndReady() and (not S.Apocalypse:CooldownUp() and (not I.InscrutableQuantumDevice:IsEquipped() or I.InscrutableQuantumDevice:CooldownRemains() > 0) or HL.FilteredFightRemains(EnemiesMelee, "<", 3)) then
    if Cast(I.DreadfireVessel, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "dreadfire_vessel trinkets 6"; end
  end
  -- use_item,name=darkmoon_deck_voracity,if=cooldown.apocalypse.remains&(!equipped.inscrutable_quantum_device|cooldown.inscrutable_quantum_device.remains)|fight_remains<21
  if I.DarkmoonDeckVoracity:IsEquippedAndReady() and (not S.Apocalypse:CooldownUp() and (not I.InscrutableQuantumDevice:IsEquipped() or I.InscrutableQuantumDevice:CooldownRemains() > 0) or HL.FilteredFightRemains(EnemiesMelee, "<", 21)) then
    if Cast(I.DarkmoonDeckVoracity, nil, Settings.Commons.DisplayStyle.Trinkets) then return "darkmoon_deck_voracity trinkets 8"; end
  end
  -- use_items,if=(cooldown.apocalypse.remains|buff.dark_transformation.up)&(!equipped.inscrutable_quantum_device|cooldown.inscrutable_quantum_device.remains)
  if ((not S.Apocalypse:CooldownUp() or Pet:BuffUp(S.DarkTransformation)) and (not I.InscrutableQuantumDevice:IsEquipped() or I.InscrutableQuantumDevice:CooldownRemains() > 0)) then
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

  -- Is Gargoyle active?
  VarGargoyleActive = S.SummonGargoyle:TimeSinceLastCast() <= 30
  VarApocGhoulActive = S.Apocalypse:TimeSinceLastCast() <= 15

  -- Set WoundSpender and AnyDnD
  WoundSpender = (S.ClawingShadows:IsAvailable() and S.ClawingShadows or S.ScourgeStrike)
  AnyDnD = S.DeathAndDecay
  if S.DeathsDue:IsAvailable() then AnyDnD = S.DeathsDue end
  if S.Defile:IsAvailable() then AnyDnD = S.Defile end

  if Everyone.TargetIsValid() then
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
    -- variable,name=specified_trinket,value=(equipped.inscrutable_quantum_device&cooldown.inscrutable_quantum_device.ready)
    -- TODO: Leaving this commented out until other trinket sync/priority variables can be handled
    --VarSpecifiedTrinket = (I.InscrutableQuantumDevice:IsEquippedAndReady())
    -- variable,name=pooling_runic_power,value=cooldown.summon_gargoyle.remains<5&talent.summon_gargoyle
    VarPoolingRunicPower = (S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:CooldownRemains() < 5)
    -- variable,name=pooling_runes,value=talent.soul_reaper&rune<2&target.time_to_pct_35<5&fight_remains>5
    VarPoolingRunes = (S.SoulReaper:IsAvailable() and Player:Rune() < 2 and Target:TimeToX(35) < 5 and HL.FilteredFightRemains(EnemiesMelee, ">", 5))
    -- variable,name=st_planning,value=active_enemies=1&(!raid_event.adds.exists|raid_event.adds.in>15)
    VarSTPlanning = (EnemiesMeleeCount == 1 or not AoEON())
    -- variable,name=major_cooldowns_active,value=pet.gargoyle.active|buff.unholy_assault.up|talent.army_of_the_damned&pet.apoc_ghoul.active|buff.dark_transformation.up
    VarMajorCDsActive = (VarGargoyleActive or Player:BuffUp(S.UnholyAssaultBuff) or S.ArmyoftheDamned:IsAvailable() and VarApocGhoulActive or Pet:BuffUp(S.DarkTransformation))
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
    -- outbreak,if=dot.virulent_plague.refreshable&!talent.unholy_blight&!raid_event.adds.exists
    -- Manually added: Use following line's Unholy Blight logic
    if S.Outbreak:IsReady() and (Target:DebuffRefreshable(S.VirulentPlagueDebuff) and (not S.UnholyBlight:IsAvailable() or S.UnholyBlight:IsAvailable() and not S.UnholyBlight:CooldownUp())) then
      if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak main 18"; end
    end
    -- outbreak,target_if=dot.virulent_plague.refreshable&active_enemies>=2&(!talent.unholy_blight|talent.unholy_blight&cooldown.unholy_blight.remains)
    -- Note: target_if handled via the EnemiesWithoutVP check
    if S.Outbreak:IsReady() and ((Target:DebuffRefreshable(S.VirulentPlagueDebuff) or EnemiesWithoutVP > 0) and EnemiesMeleeCount >= 2 and (not S.UnholyBlight:IsAvailable() or S.UnholyBlight:IsAvailable() and not S.UnholyBlight:CooldownUp())) then
      if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak main 20"; end
    end
    -- outbreak,if=runeforge.superstrain&(dot.frost_fever.refreshable|dot.blood_plague.refreshable)
    if S.Outbreak:IsReady() and (SuperstrainEquipped and (Target:DebuffRefreshable(S.FrostFeverDebuff) or Target:DebuffRefreshable(S.BloodPlagueDebuff))) then
      if Cast(S.Outbreak, nil, nil, not Target:IsSpellInRange(S.Outbreak)) then return "outbreak main 22"; end
    end
    -- wound_spender,if=covenant.night_fae&death_and_decay.active_remains<(gcd*1.5)&death_and_decay.ticking
    if WoundSpender:IsReady() and (Player:Covenant() == "Night Fae" and Player:BuffRemains(S.DeathAndDecayBuff) < (Player:GCD() * 1.5) and Player:BuffUp(S.DeathAndDecayBuff)) then
      if Cast(WoundSpender, nil, nil, not Target:IsSpellInRange(WoundSpender)) then return "wound_spender main 24"; end
    end
    -- wait_for_cooldown,name=soul_reaper,if=talent.soul_reaper&target.time_to_pct_35<5&fight_remains>5&cooldown.soul_reaper.remains<(gcd*0.75)&active_enemies=1
    -- wait_for_cooldown,name=deaths_due,if=covenant.night_fae&cooldown.deaths_due.remains<gcd&active_enemies=1
    -- wait_for_cooldown,name=defile,if=covenant.night_fae&cooldown.defile.remains<gcd&active_enemies=1
    -- TODO: Potentially add these wait_for_cooldown lines
    -- call_action_list,name=trinkets
    if (Settings.Commons.Enabled.Trinkets) then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=covenants
    if (true) then
      local ShouldReturn = Covenants(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials
    if (CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- sequence,if=active_enemies=1&!death_knight.disable_aotd,name=opener:army_of_the_dead:festering_strike:festering_strike:potion:unholy_blight:dark_transformation:apocalypse
    -- TODO: Add sequence
    -- call_action_list,name=cooldowns
    if (CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    if (AoEON()) then
      -- run_action_list,name=aoe_setup,if=active_enemies>=2&(cooldown.death_and_decay.remains<10&!talent.defile|cooldown.defile.remains<10&talent.defile)&!death_and_decay.ticking
      if (EnemiesMeleeCount >= 2 and AnyDnD:CooldownRemains() < 10 and Player:BuffDown(S.DeathAndDecayBuff)) then
        local ShouldReturn = AOE_Setup(); if ShouldReturn then return ShouldReturn; end
      end
      -- run_action_list,name=aoe_burst,if=active_enemies>=2&death_and_decay.ticking
      if (EnemiesMeleeCount >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) then
        local ShouldReturn = AOE_Burst(); if ShouldReturn then return ShouldReturn; end
      end
      -- run_action_list,name=generic_aoe,if=active_enemies>=2&(!death_and_decay.ticking&(cooldown.death_and_decay.remains>10&!talent.defile|cooldown.defile.remains>10&talent.defile))
      if (EnemiesMeleeCount >= 2 and Player:BuffDown(S.DeathAndDecayBuff) and AnyDnD:CooldownRemains() > 10) then
        local ShouldReturn = AOE_Generic(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- call_action_list,name=generic,if=active_enemies=1
    if (EnemiesMeleeCount == 1) then
      local ShouldReturn = Generic(); if ShouldReturn then return ShouldReturn; end
    end
    -- Add pool resources icon if nothing else to do
    if (true) then
      if Cast(S.PoolResources) then return "pool_resources"; end
    end
  end
end

local function Init()
  S.VirulentPlagueDebuff:RegisterAuraTracking()
  S.FesteringWoundDebuff:RegisterAuraTracking()
end

HR.SetAPL(252, APL, Init)
