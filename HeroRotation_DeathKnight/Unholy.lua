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
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Unholy;
local I = Item.DeathKnight.Unholy;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local no_heal;

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Unholy = HR.GUISettings.APL.DeathKnight.Unholy
};

-- Variables
local VarPoolingForGargoyle = 0;
local DeadliestCoilEquipped = (I.DeadliestCoilChest:IsEquipped() or I.DeadliestCoilBack:IsEquipped())

--Functions
local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end
HL:RegisterForEvent(function()
  VarPoolingForGargoyle = 0
end, "PLAYER_REGEN_ENABLED")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function DeathStrikeHeal()
  return (Settings.General.SoloMode and (Player:HealthPercentage() < Settings.Commons.UseDeathStrikeHP or Player:HealthPercentage() < Settings.Commons.UseDarkSuccorHP and Player:BuffUp(S.DeathStrikeBuff)))
end

local function DisableAOTD()
  return (S.ArmyoftheDead:CooldownRemains() > 5 or Settings.Unholy.AotDOff)
end
-- Festering Wound TargetIf Conditions
local function EvaluateTargetUnitNoFWDebuff(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 1)
end
local function EvaluateTargetIfFWStacks(TargetUnit)
  return (S.Apocalypse:CooldownRemains() > 5 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 1)
end
local function EvaluateTargetIfFWExists(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff))
end
local function EvaluateTargetIfFWBuild(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 3 and S.Apocalypse:CooldownRemains() < 3 or TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 1)
end
-- Apocalypse Conditions
local function EvaluateTargetIfApocalypse(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 4 and EnemiesMeleeCount >= 2 and not Player:BuffUp(S.DeathAndDecayBuff) )
end
-- Unholy Assault Conditions
local function EvaluateTargetIfUnholyAssault(TargetUnit)
  return (EnemiesMeleeCount >= 2 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) < 2)
end
-- Soul Reaper Conditions
local function EvaluateCycleSoulReaper(TargetUnit)
  return (TargetUnit:HealthPercentage() < 35 and TargetUnit:TimeToDie() > 5)
end
-- Scourge Strike / Clawing Shadow TargetIf Conditions
local function EvaluateTargetIfScourgeClaw(TargetUnit)
  return (S.Apocalypse:CooldownRemains() > 5 and TargetUnit:DebuffStack(S.FesteringWoundDebuff) >= 1)
end
local function EvaluateCycleScourgeClaw(TargetUnit)
  return (DisableAOTD() and (S.Apocalypse:CooldownRemains() > 5 and TargetUnit:DebuffUp(S.FesteringWoundDebuff) or TargetUnit:DebuffStack(S.FesteringWoundDebuff) > 4) and (TargetUnit:TimeToDie() < S.DeathAndDecay:CooldownRemains() + 10 or TargetUnit:TimeToDie() > S.Apocalypse:CooldownRemains()))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  -- raise_dead
  if S.RaiseDead:IsCastable() then
    if HR.CastSuggested(S.RaiseDead) then return "raise_dead 6"; end
  end
  if Everyone.TargetIsValid() then
    -- army_of_the_dead,precombat_time=2
    if S.ArmyoftheDead:IsCastable() then
      if HR.Cast(S.ArmyoftheDead, Settings.Unholy.GCDasOffGCD.ArmyoftheDead) then return "army_of_the_dead 8"; end
    end
  end
end

local function AOE_Setup()
  -- death_and_decay,if=death_knight.fwounded_targets=active_enemies|raid_event.adds.exists&raid_event.adds.remains<=11
  if S.DeathAndDecay:IsCastable() and (S.FesteringWoundDebuff:AuraActiveCount() == EnemiesMeleeCount) then
    if HR.Cast(S.DeathAndDecay, Settings.Unholy.GCDasOffGCD.DeathAndDecay) then return "death_and_decay aoe_setup 1"; end
  end
  -- death_and_decay,if=death_knight.fwounded_targets>=5
  if S.DeathAndDecay:IsCastable() and S.FesteringWoundDebuff:AuraActiveCount() >= 5 then
    if HR.Cast(S.DeathAndDecay, Settings.Unholy.GCDasOffGCD.DeathAndDecay) then return "death_and_decay aoe_setup 2"; end
  end
  -- defile,if=death_knight.fwounded_targets=active_enemies|raid_event.adds.exists&raid_event.adds.remains<=11
  if S.Defile:IsCastable() and (S.FesteringWoundDebuff:AuraActiveCount() == EnemiesMeleeCount) then
    if HR.Cast(S.Defile) then return "defile aoe_setup 3"; end
  end
  -- defile,if=death_knight.fwounded_targets>=5
  if S.Defile:IsCastable() and S.FesteringWoundDebuff:AuraActiveCount() >= 5 then
    if HR.Cast(S.Defile) then return "defile aoe_setup 4"; end
  end
  -- epidemic,if=!variable.pooling_for_gargoyle&runic_power.deficit<20
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReady() and not bool(VarPoolingForGargoyle) and Player:RunicPowerDeficit() < 20 and S.VirulentPlagueDebuff:AuraActiveCount() > 1 then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic aoe_setup 5"; end
  end
  -- festering_strike,target_if=debuff.festering_wound.stack<1
  if S.FesteringStrike:IsCastable() then
    if Everyone.CastCycle(S.FesteringStrike, EnemiesMelee, EvaluateTargetUnitNoFWDebuff) then return "festering_strike target_if aoe_setup 6" end
  end 
  -- epidemic,if=!variable.pooling_for_gargoyle
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReady() and not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:AuraActiveCount() > 1 then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic aoe_setup 7"; end
  end
end

local function AOE_Burst()
  -- epidemic,if=runic_power.deficit<(10+death_knight.fwounded_targets*3)&death_knight.fwounded_targets<6&!variable.pooling_for_gargoyle
  if S.Epidemic:IsReady() and (Player:RunicPowerDeficit() < (10 + S.FesteringWoundDebuff:AuraActiveCount() * 3) and S.FesteringWoundDebuff:AuraActiveCount() < 6 and not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:AuraActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic aoe_burst 1"; end
  end
  -- epidemic,if=runic_power.deficit<25&death_knight.fwounded_targets>5&!variable.pooling_for_gargoyle
  if S.Epidemic:IsReady() and (Player:RunicPowerDeficit() < 25 and S.FesteringWoundDebuff:AuraActiveCount() > 5 and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic aoe_burst 2"; end
  end
  -- epidemic,if=!death_knight.fwounded_targets&!variable.pooling_for_gargoyle
  if S.Epidemic:IsReady() and (S.FesteringWoundDebuff:AuraActiveCount() < 1 and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic aoe_burst 3"; end
  end
  -- scourge_strike
  if S.ScourgeStrike:IsCastable() then
    if HR.Cast(S.ScourgeStrike, nil, nil, not TargetIsInRange[8]) then return "scourge_strike aoe_burst 4"; end
  end
  -- clawing_shadows
  if S.ClawingShadows:IsCastable() then
    if HR.Cast(S.ClawingShadows, nil, nil, not TargetIsInRange[30]) then return "clawing_shadows aoe_burst 5"; end
  end
  -- epidemic,if=!variable.pooling_for_gargoyle
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReady() and (not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:AuraActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic aoe_burst 6"; end
  end
end

local function AOE_Generic()
  -- epidemic,if=buff.sudden_doom.react
  if S.Epidemic:IsReady() and Player:BuffUp(S.SuddenDoomBuff) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic aoe_generic 1"; end
  end
  -- epidemic,if=!variable.pooling_for_gargoyle
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReady() and (not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:AuraActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic aoe_generic 2"; end
  end
  -- scourge_strike,target_if=max:debuff.festering_wound.stack,if=cooldown.apocalypse.remains>5&debuff.festering_wound.stack>=1
  if S.ScourgeStrike:IsCastable() then
    if Everyone.CastCycle(S.ScourgeStrike, EnemiesMelee, EvaluateTargetIfScourgeClaw) then return "scourge_strike target_if aoe_generic 3"; end
  end
  -- clawing_shadows,target_if=max:debuff.festering_wound.stack,if=cooldown.apocalypse.remains>5&debuff.festering_wound.stack>=1
  if S.ClawingShadows:IsCastable() then
    if Everyone.CastCycle(S.ClawingShadows, Enemies30yd, EvaluateTargetIfScourgeClaw) then return "clawing_shadow target_if aoe_generic 4"; end
  end
    -- festering_strike,target_if=min:debuff.festering_wound.stack,if=cooldown.apocalypse.remains>5&debuff.festering_wound.stack<1
  if S.FesteringStrike:IsCastable() then
    if Everyone.CastCycle(S.FesteringStrike, EnemiesMelee, EvaluateTargetIfFWStacks) then return "festering_strike target_if aoe_generic 5"; end
  end
  -- scourge_strike,target_if=max:debuff.festering_wound.stack,if=(cooldown.apocalypse.remains>5&debuff.festering_wound.up|debuff.festering_wound.stack>4)&(target.1.time_to_die<cooldown.death_and_decay.remains+10|target.1.time_to_die>cooldown.apocalypse.remains)
  if S.ScourgeStrike:IsCastable() then
    if Everyone.CastCycle(S.ScourgeStrike, EnemiesMelee, EvaluateCycleScourgeClaw) then return "scourge_strike target_if aoe_generic 6"; end
  end
  -- clawing_shadows,target_if=max:debuff.festering_wound.stack,if=(cooldown.apocalypse.remains>5&debuff.festering_wound.up|debuff.festering_wound.stack>4)&(target.1.time_to_die<cooldown.death_and_decay.remains+10|target.1.time_to_die>cooldown.apocalypse.remains)
  if S.ClawingShadows:IsCastable() then
    if Everyone.CastCycle(S.ClawingShadows, Enemies30yd, EvaluateCycleScourgeClaw) then return "clawing_shadow target_if aoe_generic 7"; end
  end
  -- festering_strike,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack<3&cooldown.apocalypse.remains<3|debuff.festering_wound.stack<1
  if S.FesteringStrike:IsCastable() then
    if Everyone.CastCycle(S.FesteringStrike, EnemiesMelee, EvaluateTargetIfFWBuild) then return "festering_strike target_if aoe_generic 8"; end
  end
end

local function Cooldowns()
  -- army_of_the_dead,if=cooldown.unholy_blight.remains<5&talent.unholy_blight.enabled|!talent.unholy_blight.enabled
  if S.ArmyoftheDead:IsCastable() and (S.UnholyBlight:CooldownRemains() < 5 and S.UnholyBlight:IsAvailable() or not S.UnholyBlight:IsAvailable()) then
    if HR.Cast(S.ArmyoftheDead, Settings.Unholy.GCDasOffGCD.ArmyoftheDead) then return "army_of_the_dead cooldown 1"; end
  end
  -- unholy_blight,if=(cooldown.army_of_the_dead.remains>5|death_knight.disable_aotd)&(cooldown.apocalypse.ready&(debuff.festering_wound.stack>=4|rune>=3)|cooldown.apocalypse.remains)&!raid_event.adds.exists
  if S.UnholyBlight:IsCastable() and (DisableAOTD() and (S.Apocalypse:CooldownUp() and (Target:DebuffStack(S.FesteringWoundDebuff) >= 4 or Player:Rune() >= 3) or bool(S.Apocalypse:CooldownRemains()))) then
    if HR.Cast(S.UnholyBlight, nil, nil, not TargetIsInRange[10]) then return "unholy_blight cooldown 2"; end
  end
  -- unholy_blight,if=raid_event.adds.exists&(active_enemies>=2|raid_event.adds.in>15)
  if S.UnholyBlight:IsCastable() and EnemiesMeleeCount >= 2 then
    if HR.Cast(S.UnholyBlight, nil, nil, not TargetIsInRange[10]) then return "unholy_blight cooldown 3"; end
  end
  -- dark_transformation,if=!raid_event.adds.exists&cooldown.unholy_blight.remains&(runeforge.deadliest_coil.equipped&(!buff.dark_transformation.up&!talent.unholy_pact.enabled|talent.unholy_pact.enabled)|!runeforge.deadliest_coil.equipped)|!talent.unholy_blight.enabled
  if S.DarkTransformation:IsCastable() and (bool(S.UnholyBlight:CooldownRemains()) and (DeadliestCoilEquipped and (not Pet:BuffUp(S.DarkTransformation) and not S.UnholyPact:IsAvailable() or S.UnholyPact:IsAvailable()) or not DeadliestCoilEquipped) or not S.UnholyBlight:IsAvailable()) then
    if HR.Cast(S.DarkTransformation) then return "dark_transformation cooldown 4"; end
  end
  -- dark_transformation,if=raid_event.adds.exists&(active_enemies>=2|raid_event.adds.in>15)
  if S.DarkTransformation:IsCastable() and EnemiesMeleeCount >= 2 then
    if HR.Cast(S.DarkTransformation) then return "dark_transformation cooldown 5"; end
  end
  -- unholy_assault,if=active_enemies=1&(pet.apoc_ghoul.active|conduit.convocation_of_the_dead.enabled)
  if S.UnholyAssault:IsCastable() and (EnemiesMeleeCount == 1 and (S.Apocalypse:TimeSinceLastCast() <= 15) or S.ConvocationOfTheDead:IsAvailable()) then
    if HR.Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault) then return "unholy_assault cooldown 6"; end
  end
  -- unholy_assault,target_if=min:debuff.festering_wound.stack,if=active_enemies>=2&debuff.festering_wound.stack<2
  if S.UnholyAssault:IsCastable() then
    if Everyone.CastCycle(S.UnholyAssault, EnemiesMelee, EvaluateTargetIfUnholyAssault) then return "unholy_assault target_if cooldown 7"; end
  end
  -- apocalypse,if=debuff.festering_wound.stack>=4&((!talent.unholy_blight.enabled|talent.army_of_the_damned.enabled|conduit.convocation_of_the_dead.enabled)|talent.unholy_blight.enabled&!talent.army_of_the_damned.enabled&dot.unholy_blight.remains)&active_enemies=1
  if S.Apocalypse:IsCastable() and (Target:DebuffStack(S.FesteringWoundDebuff) >= 4 and ((not S.UnholyBlight:IsAvailable() or S.ArmyoftheDamned:IsAvailable() or S.ConvocationOfTheDead:IsAvailable()) or S.UnholyBlight:IsAvailable() and not S.ArmyoftheDamned:IsAvailable() and Target:DebuffUp(S.UnholyBlightDebuff)) and EnemiesMeleeCount == 1) then
    if HR.Cast(S.Apocalypse) then return "apocalypse cooldown 8"; end
  end
  -- apocalypse,target_if=max:debuff.festering_wound.stack,if=debuff.festering_wound.stack>=4&active_enemies>=2&!death_and_decay.ticking
  if S.Apocalypse:IsCastable() then
    if Everyone.CastTargetIf(S.Apocalypse, EnemiesMelee, "max", EvaluateTargetIfFWExists, EvaluateTargetIfApocalypse) then return "apocalypse target_if cooldown 9"; end
  end
  -- summon_gargoyle,if=runic_power.deficit<14
  if S.SummonGargoyle:IsCastable() and (Player:RunicPowerDeficit() < 14) then
    if HR.Cast(S.SummonGargoyle) then return "summon_gargoyle cooldown 10"; end
  end
  -- soul_reaper,target_if=target.health.pct<35&target.time_to_die>5
  if S.SoulReaper:IsCastable() then
    if Everyone.CastCycle(S.SoulReaper, EnemiesMelee, EvaluateCycleSoulReaper) then return "soul_reaper target_if cooldown 11" end
  end
  -- raise_dead,if=!pet.risen_ghoul.active
  if S.RaiseDead:IsCastable() then
    if HR.CastSuggested(S.RaiseDead) then return "raise_dead cooldown 12"; end
  end
  -- sacrificial_pact,if=active_enemies>=2&!buff.dark_transformation.up&!cooldown.dark_transformation.ready 
  if S.SacrificialPact:IsCastable() and (EnemiesMeleeCount >= 2 and not Pet:BuffUp(S.DarkTransformation) and not S.DarkTransformation:CooldownUp() and S.RaiseDead:CooldownUp()) then
    if HR.Cast(S.SacrificialPact, Settings.Commons.GCDasOffGCD.SacrificialPact, nil, not TargetIsInRange[8]) then return "sacrificial_pact cooldown 13"; end
  end
end

local function Racials()
  if (HR.CDsON()) then
    -- arcane_torrent,if=runic_power.deficit>65&pet.gargoyle.active&rune.deficit>=5
    if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 65 and S.SummonGargoyle:TimeSinceLastCast() <= 35 and Player:Rune() <= 1) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[8]) then return "arcane_torrent racial 1"; end
    end
    -- blood_fury,if=pet.gargoyle.active|buff.unholy_assault.up|talent.army_of_the_damned.enabled&(pet.army_ghoul.active|cooldown.army_of_the_dead.remains>target.time_to_die)
    if S.BloodFury:IsCastable() and (S.SummonGargoyle:TimeSinceLastCast() <= 35 and S.SummonGargoyle:IsAvailable() or S.UnholyAssault:BuffUp() and S.UnholyAssault:IsAvailable() or S.ArmyoftheDamned:IsAvailable() and (ArmyoftheDead:TimeSinceLastCast() <= 30 or S.ArmyoftheDead:CooldownRemains() > Target:TimeToDie())) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial 2"; end
    end
    -- berserking,if=pet.gargoyle.active|buff.unholy_assault.up|talent.army_of_the_damned.enabled&(pet.army_ghoul.active|cooldown.army_of_the_dead.remains>target.time_to_die)
    if S.Berserking:IsCastable() and (S.SummonGargoyle:TimeSinceLastCast() <= 35 and S.SummonGargoyle:IsAvailable() or S.UnholyAssault:BuffUp() and S.UnholyAssault:IsAvailable() or S.ArmyoftheDamned:IsAvailable() and (ArmyoftheDead:TimeSinceLastCast() <= 30 or S.ArmyoftheDead:CooldownRemains() > Target:TimeToDie())) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial 3"; end
    end
    -- lights_judgment,if=buff.unholy_strength.up
    if S.LightsJudgment:IsCastable() and Player:BuffUp(S.UnholyStrengthBuff) then
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "lights_judgment racial 4"; end
    end
    -- ancestral_call,if=pet.gargoyle.active|buff.unholy_assault.up|talent.army_of_the_damned.enabled&(pet.army_ghoul.active|cooldown.army_of_the_dead.remains>target.time_to_die)
    if S.AncestralCall:IsCastable() and (S.SummonGargoyle:TimeSinceLastCast() <= 35 and S.SummonGargoyle:IsAvailable() or S.UnholyAssault:BuffUp() and S.UnholyAssault:IsAvailable() or S.ArmyoftheDamned:IsAvailable() and (ArmyoftheDead:TimeSinceLastCast() <= 30 or S.ArmyoftheDead:CooldownRemains() > Target:TimeToDie())) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial 5"; end
    end
    -- arcane_pulse,if=active_enemies>=2|(rune.deficit>=5&runic_power.deficit>=60)
    if S.ArcanePulse:IsCastable() and (EnemiesMeleeCount >= 2 or (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
      if HR.Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[8]) then return "arcane_pulse racial 6"; end
    end
    -- fireblood, if=pet.gargoyle.active|buff.unholy_assault.up|talent.army_of_the_damned.enabled&(pet.army_ghoul.active|cooldown.army_of_the_dead.remains>target.time_to_die)
    if S.Fireblood:IsCastable() and (S.SummonGargoyle:TimeSinceLastCast() <= 35 and S.SummonGargoyle:IsAvailable() or S.UnholyAssault:BuffUp() and S.UnholyAssault:IsAvailable() or S.ArmyoftheDamned:IsAvailable() and (ArmyoftheDead:TimeSinceLastCast() <= 30 or S.ArmyoftheDead:CooldownRemains() > Target:TimeToDie())) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial 7"; end
    end
    -- bag_of_tricks,if=buff.unholy_strength.up&active_enemies=1
    if S.BagofTricks:IsCastable() and Player:BuffUp(S.UnholyStrengthBuff) and EnemiesMeleeCount == 1 then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[30]) then return "bag_of_tricks racial 8"; end
    end
  end
end

local function Generic()
  -- death_coil,if=buff.sudden_doom.react&!variable.pooling_for_gargoyle|pet.gargoyle.active
  if S.DeathCoil:IsUsable() and (Player:BuffUp(S.SuddenDoomBuff)  and not bool(VarPoolingForGargoyle) or S.SummonGargoyle:TimeSinceLastCast() <= 35) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil generic 1"; end
  end
  -- death_coil,if=runic_power.deficit<14&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and (Player:RunicPowerDeficit() < 14 and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil generic 2"; end
  end
  -- defile,if=cooldown.apocalypse.remains
  if S.Defile:IsCastable() and bool(S.Apocalypse:CooldownRemains()) then
    if HR.Cast(S.Defile, Settings.Unholy.GCDasOffGCD.Defile) then return "defile generic 3"; end
  end
  -- scourge_strike,if=debuff.festering_wound.up&(!talent.unholy_blight.enabled|talent.army_of_the_damned.enabled|conduit.convocation_of_the_dead.enabled|raid_event.adds.exists)&cooldown.apocalypse.remains>5
  if S.ScourgeStrike:IsCastable() and (Target:DebuffUp(S.FesteringWoundDebuff) and (not S.UnholyBlight:IsAvailable() or S.ArmyoftheDamned:IsAvailable() or S.ConvocationOfTheDead:IsAvailable()) and S.Apocalypse:CooldownRemains() > 5) then
    if HR.Cast(S.ScourgeStrike, nil, nil, not TargetIsInRange[8]) then return "scourge_strike generic 4"; end
  end
  -- scourge_strike,if=debuff.festering_wound.stack>4
  if S.ScourgeStrike:IsCastable() and Target:DebuffStack(S.FesteringWoundDebuff) > 4  then
    if HR.Cast(S.ScourgeStrike, nil, nil, not TargetIsInRange[8]) then return "scourge_strike generic 5"; end
  end
  -- scourge_strike,if=debuff.festering_wound.up&talent.unholy_blight.enabled&!talent.army_of_the_damned.enabled&cooldown.unholy_blight.remains>5&!cooldown.apocalypse.ready&!raid_event.adds.exists
  if S.ScourgeStrike:IsCastable() and (Target:DebuffUp(S.FesteringWoundDebuff) and S.UnholyBlight:IsAvailable() and not S.ArmyoftheDamned:IsAvailable() and S.UnholyBlight:CooldownRemains() > 5 and not S.Apocalypse:CooldownUp())  then
    if HR.Cast(S.ScourgeStrike, nil, nil, not TargetIsInRange[8]) then return "scourge_strike generic 6"; end
  end
  -- clawing_shadows,if=debuff.festering_wound.up&(!talent.unholy_blight.enabled|talent.army_of_the_damned.enabled|conduit.convocation_of_the_dead.enabled|raid_event.adds.exists)&cooldown.apocalypse.remains>5
  if S.ClawingShadows:IsCastable() and (Target:DebuffUp(S.FesteringWoundDebuff) and (not S.UnholyBlight:IsAvailable() or S.ArmyoftheDamned:IsAvailable() or S.ConvocationOfTheDead:IsAvailable()) and S.Apocalypse:CooldownRemains() > 5) then
    if HR.Cast(S.ClawingShadows, nil, nil, not TargetIsInRange[30]) then return "clawing_shadows generic 7"; end
  end
  -- clawing_shadows,if=debuff.festering_wound.stack>4
  if S.ClawingShadows:IsCastable() and Target:DebuffStack(S.FesteringWoundDebuff) > 4  then
    if HR.Cast(S.ClawingShadows, nil, nil, not TargetIsInRange[30]) then return "clawing_shadows generic 8"; end
  end
  -- clawing_shadows,if=debuff.festering_wound.up&talent.unholy_blight.enabled&!talent.army_of_the_damned.enabled&cooldown.unholy_blight.remains>5&!cooldown.apocalypse.ready&!raid_event.adds.exists
  if S.ClawingShadows:IsCastable() and (Target:DebuffUp(S.FesteringWoundDebuff) and S.UnholyBlight:IsAvailable() and not S.ArmyoftheDamned:IsAvailable() and S.UnholyBlight:CooldownRemains() > 5 and not S.Apocalypse:CooldownUp())  then
    if HR.Cast(S.ClawingShadows, nil, nil, not TargetIsInRange[30]) then return "clawing_shadows generic 9"; end
  end
  -- death_coil,if=runic_power.deficit<20&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and (Player:RunicPowerDeficit() < 20 and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil generic 10"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<4&cooldown.apocalypse.remains<3&(!talent.unholy_blight.enabled|talent.army_of_the_damned.enabled|conduit.convocation_of_the_dead.enabled|raid_event.adds.exists)
  if S.FesteringStrike:IsCastable() and (Target:DebuffStack(S.FesteringWoundDebuff) < 4 and S.Apocalypse:CooldownRemains() < 3 and (not S.UnholyBlight:IsAvailable() or S.ArmyoftheDamned:IsAvailable() or S.ConvocationOfTheDead:IsAvailable())) then
    if HR.Cast(S.FesteringStrike, nil, nil, not TargetIsInRange[8]) then return "festering_strike generic 11"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<1
  if S.FesteringStrike:IsCastable() and Target:DebuffStack(S.FesteringWoundDebuff) < 1 then
    if HR.Cast(S.FesteringStrike, nil, nil, not TargetIsInRange[8]) then return "festering_strike generic 12"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<4&(cooldown.unholy_blight.remains<3|(cooldown.apocalypse.ready&dot.unholy_blight.remains)&talent.unholy_blight.enabled&!talent.army_of_the_damned.enabled)&!raid_event.adds.exists
  if S.FesteringStrike:IsCastable() and (Target:DebuffStack(S.FesteringWoundDebuff) < 4 and (S.UnholyBlight:CooldownRemains() < 3 or (S.Apocalypse:CooldownUp() and Target:DebuffUp(S.UnholyBlightDebuff)) and S.UnholyBlight:IsAvailable() and not S.ArmyoftheDamned:IsAvailable())) then
    if HR.Cast(S.FesteringStrike, nil, nil, not TargetIsInRange[8]) then return "festering_strike generic 13"; end
  end
  -- death_coil,if=!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and (not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil generic 14"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  no_heal = not DeathStrikeHeal()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(8)
  Enemies30yd = Player:GetEnemiesInRange(30)
  EnemiesMeleeCount = #EnemiesMelee
  ComputeTargetRange()

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, false); if ShouldReturn then return ShouldReturn; end
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReady() and not no_heal then
      if HR.Cast(S.DeathStrike) then return "death_strike low hp or proc"; end
    end
    -- auto_attack
    -- variable,name=pooling_for_gargoyle,value=cooldown.summon_gargoyle.remains<5&talent.summon_gargoyle.enabled
    if (true) then
      VarPoolingForGargoyle = num(S.SummonGargoyle:CooldownRemains() < 5 and S.SummonGargoyle:IsAvailable())
    end

    --Settings.Commons.UseTrinkets

    -- outbreak,target_if=dot.virulent_plague.remains<=gcd
    if S.Outbreak:IsCastable() and Target:DebuffRemains(S.VirulentPlagueDebuff) <= Player:GCD() then
      if HR.Cast(S.Outbreak, nil, nil, not TargetIsInRange[30]) then return "outbreak refresh" end
    end
    -- Death Coil/Epidemic when we are not in melee range
    if not Target:IsInMeleeRange(8) then
      if  S.Epidemic:IsUsable() and S.VirulentPlagueDebuff:AuraActiveCount() > 1 then
        if HR.Cast(S.Epidemic, nil, nil, not TargetIsInRange[100]) then return "epidemic out of range"; end
      end
      if S.DeathCoil:IsUsable() then
        if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil out of range"; end
      end
    end
    -- call_action_list,name=cooldowns
    if (true and HR.CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- racials
    if (true and HR.CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    if HR.AoEON() then
      -- run_action_list,name=aoe_setup,if=active_enemies>=2&(cooldown.death_and_decay.remains<10&!talent.defile.enabled|cooldown.defile.remains<10&talent.defile.enabled)&!death_and_decay.ticking
      if (EnemiesMeleeCount >= 2 and (S.DeathAndDecay:CooldownRemains() < 10 and not S.Defile:IsAvailable() or S.Defile:CooldownRemains() < 10 and S.Defile:IsAvailable()) and not Player:BuffUp(S.DeathAndDecayBuff)) then
        local ShouldReturn = AOE_Setup(); if ShouldReturn then return ShouldReturn; end
      end
      -- run_action_list,name=aoe_burst,if=active_enemies>=2&death_and_decay.ticking
      if (EnemiesMeleeCount >= 2 and Player:BuffUp(S.DeathAndDecayBuff)) then
        local ShouldReturn = AOE_Burst(); if ShouldReturn then return ShouldReturn; end
      end
      -- generic_aoe,if=active_enemies>=2&(!death_and_decay.ticking&(cooldown.death_and_decay.remains>10&!talent.defile.enabled|cooldown.defile.remains>10&talent.defile.enabled))
      if (EnemiesMeleeCount >= 2 and (not Player:BuffUp(S.DeathAndDecayBuff) and (S.DeathAndDecay:CooldownRemains() > 10 and not S.Defile:IsAvailable() or S.Defile:CooldownRemains() > 10 and S.Defile:IsAvailable()))) then
        local ShouldReturn = AOE_Generic(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- call_action_list,name=generic,if=active_enemies=1
    if (EnemiesMeleeCount == 1 or (EnemiesMeleeCount > 1 and not HR.AoEON())) then
      local ShouldReturn = Generic(); if ShouldReturn then return ShouldReturn; end
    end
    -- Add pool resources icon if nothing else to do
    if (true) then
      if HR.Cast(S.PoolResources) then return "pool_resources"; end
    end
  end
end

local function Init()
  S.VirulentPlagueDebuff:RegisterAuraTracking();
  S.FesteringWoundDebuff:RegisterAuraTracking();
end

HR.SetAPL(252, APL, Init)
