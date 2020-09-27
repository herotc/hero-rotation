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
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.DeathKnight then Spell.DeathKnight = {} end
Spell.DeathKnight.Unholy = {
  -- Abilities
  RaiseDead                             = Spell(46584),
  SacrificialPact                       = Spell(327574),
  ArmyoftheDead                         = Spell(42650),
  Apocalypse                            = Spell(275699),
  DeathAndDecay                         = Spell(43265),
  Epidemic                              = Spell(207317),
  FesteringStrike                       = Spell(85948),
  DeathCoil                             = Spell(47541),
  ScourgeStrike                         = Spell(55090),
  Outbreak                              = Spell(77575),
  DeathStrike                           = Spell(49998),
  DarkTransformation                    = Spell(63560),
  -- Talents
  Defile                                = Spell(152280),
  BurstingSores                         = Spell(207264),
  ClawingShadows                        = Spell(207311),
  SoulReaper                            = Spell(130736),
  UnholyBlight                          = Spell(115989),
  SummonGargoyle                        = MultiSpell(49206, 207349),
  Pestilence                            = Spell(277234),
  UnholyAssault                         = Spell(207289),
  ArmyoftheDamned                       = Spell(276837),
  -- Covenant Abilities
  ShackleTheUnworthy                    = Spell(312202),
  SwarmingMist                          = Spell(311648),
  AbominationLimb                       = Spell(315443),
  DeathsDue                             = Spell(324128),
  -- Conduit Effects
  -- Buffs
  DeathAndDecayBuff                     = Spell(188290),
  DeathStrikeBuff                       = Spell(101568),
  SuddenDoomBuff                        = Spell(81340),
  UnholyAssaultBuff                     = Spell(207289),
  UnholyStrengthBuff                    = Spell(53365),
  -- Debuffs
  FesteringWoundDebuff                  = Spell(194310),
  VirulentPlagueDebuff                  = Spell(191587),
  UnholyBlightDebuff                    = Spell(115994),
  -- Racials
  ArcaneTorrent                         = Spell(50613),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  LightsJudgment                        = Spell(255647),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  ArcanePulse                           = Spell(260364),
  Fireblood                             = Spell(265221),
  -- Interrupts
  MindFreeze                            = Spell(47528),
  -- Custom
  PoolResources                         = Spell(999910)
};
local S = Spell.DeathKnight.Unholy;

-- Items
if not Item.DeathKnight then Item.DeathKnight = {} end
Item.DeathKnight.Unholy = {
  -- Potions/Trinkets
  -- "Other On Use"
  DeadliestCoilChest = Item(171412),
  DeadliestCoilBack = Item(173242)
};
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

local function EvaluateCycleFesteringStrike(TargetUnit)
  return (TargetUnit:DebuffStack(S.FesteringWoundDebuff) <= 2 and not S.DeathAndDecay:CooldownUp() and S.Apocalypse:CooldownRemains() > 5 and DisableAOTD())
end

local function EvaluateCycleSoulReaper(TargetUnit)
  return (TargetUnit:HealthPercentage() < 35 and TargetUnit:TimeToDie() > 5)
end

local function EvaluateCycleOutbreak(TargetUnit)
  return TargetUnit:DebuffRemains(S.VirulentPlagueDebuff) <= Player:GCD()
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

local function Aoe()
  -- death_and_decay,if=cooldown.apocalypse.remains
  if S.DeathAndDecay:IsCastable() and (not S.Apocalypse:CooldownUp()) then
    if HR.Cast(S.DeathAndDecay, Settings.Unholy.GCDasOffGCD.DeathAndDecay) then return "death_and_decay 10"; end
  end
  -- defile,if=cooldown.apocalypse.remains
  if S.Defile:IsCastable() and (not S.Apocalypse:CooldownUp()) then
    if HR.Cast(S.Defile) then return "defile 14"; end
  end
  -- death_and_decay.ticking&runic_power.deficit<(14+death_knight.fwounded_targets*3)&!variable.pooling_for_gargoyle
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and Player:RunicPowerDeficit() < (14 + S.FesteringWoundDebuff:AuraActiveCount() * 3) and not bool(VarPoolingForGargoyle)) and S.VirulentPlagueDebuff:AuraActiveCount() > 1 then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic 16"; end
  end
  -- epidemic,if=death_and_decay.ticking&(!death_knight.fwounded_targets&talent.bursting_sores.enabled)&!variable.pooling_for_gargoyle
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and (S.FesteringWoundDebuff:AuraActiveCount() == 0 and S.BurstingSores:IsAvailable()) and not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:AuraActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic 18"; end
  end
  -- scourge_strike,if=death_and_decay.ticking&cooldown.apocalypse.remains
  if S.ScourgeStrike:IsCastable() and (Player:BuffUp(S.DeathAndDecayBuff) and not S.Apocalypse:CooldownUp()) then
    if HR.Cast(S.ScourgeStrike, nil, nil, not TargetIsInRange[8]) then return "scourge_strike 24"; end
  end
  -- clawing_shadows,if=death_and_decay.ticking&cooldown.apocalypse.remains
  if S.ClawingShadows:IsCastable() and (Player:BuffUp(S.DeathAndDecayBuff) and not S.Apocalypse:CooldownUp()) then
    if HR.Cast(S.ClawingShadows, nil, nil, not TargetIsInRange[30]) then return "clawing_shadows 28"; end
  end
  -- epidemic,if=!variable.pooling_for_gargoyle
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReady() and (not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:AuraActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic 32"; end
  end
  -- festering_strike,target_if=debuff.festering_wound.stack<=2&cooldown.death_and_decay.remains&cooldown.apocalypse.remains>5&variable.disable_aotd
  if S.FesteringStrike:IsCastable() then
    if Everyone.CastCycle(S.FesteringStrike, Enemies30yd, EvaluateCycleFesteringStrike) then return "festering_strike 46" end
  end
  -- death_coil,if=buff.sudden_doom.react&rune.time_to_4>gcd
  if S.DeathCoil:IsUsable() and (Player:BuffUp(S.SuddenDoomBuff) and Player:RuneTimeToX(4) > Player:GCD()) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil 53"; end
  end
  -- death_coil,if=buff.sudden_doom.react&!variable.pooling_for_gargoyle|pet.gargoyle.active
  if S.DeathCoil:IsUsable() and (Player:BuffUp(S.SuddenDoomBuff) and not bool(VarPoolingForGargoyle) or S.SummonGargoyle:TimeSinceLastCast() <= 35) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil 57"; end
  end
  -- death_coil,if=runic_power.deficit<14&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and (Player:RunicPowerDeficit() < 14 and (S.Apocalypse:CooldownRemains() > 5 or Target:DebuffStack(S.FesteringWoundDebuff) > 4) and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil 63"; end
  end
  -- scourge_strike,target_if=(variable.disable_aotd&(cooldown.apocalypse.remains>5&debuff.festering_wound.stack>0|debuff.festering_wound.stack>4)&(target.1.time_to_die<cooldown.death_and_decay.remains+10|target.1.time_to_die>cooldown.apocalypse.remains))
  if S.ScourgeStrike:IsCastable() then
    if Everyone.CastCycle(S.ScourgeStrike, EnemiesMelee, EvaluateCycleScourgeClaw) then return "scourge_strike 71"; end
  end
  -- clawing_shadows,target_if=(variable.disable_aotd&(cooldown.apocalypse.remains>5&debuff.festering_wound.stack>0|debuff.festering_wound.stack>4)&(target.1.time_to_die<cooldown.death_and_decay.remains+10|target.1.time_to_die>cooldown.apocalypse.remains))
  if S.ClawingShadows:IsCastable() then
    if Everyone.CastCycle(S.ClawingShadows, Enemies30yd, EvaluateCycleScourgeClaw) then return "clawing_shadows 81"; end
  end
  -- death_coil,if=runic_power.deficit<20&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and (Player:RunicPowerDeficit() < 20 and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil 91"; end
  end
  -- festering_strike,if=((((debuff.festering_wound.stack<4&!buff.unholy_assault.up)|debuff.festering_wound.stack<3)&cooldown.apocalypse.remains<3)|debuff.festering_wound.stack<1)&variable.disable_aotd
  if S.FesteringStrike:IsCastable() and (((((Target:DebuffStack(S.FesteringWoundDebuff) < 4 and Player:BuffDown(S.UnholyAssaultBuff)) or Target:DebuffStack(S.FesteringWoundDebuff) < 3) and S.Apocalypse:CooldownRemains() < 3) or Target:DebuffStack(S.FesteringWoundDebuff) < 1) and DisableAOTD()) then
    if HR.Cast(S.FesteringStrike, nil, nil, not TargetIsInRange[8]) then return "festering_strike 95"; end
  end
  -- scourge_strike,if=death_and_decay.ticking
  if S.ScourgeStrike:IsCastable() and (Player:BuffUp(S.DeathAndDecayBuff)) then
    if HR.Cast(S.ScourgeStrike, nil, nil, not TargetIsInRange[8]) then return "scourge_strike 97"; end
  end
  -- clawing_shadows,if=death_and_decay.ticking
  if S.ClawingShadows:IsCastable() and (Player:BuffUp(S.DeathAndDecayBuff)) then
    if HR.Cast(S.ClawingShadows, nil, nil, not TargetIsInRange[30]) then return "clawing_shadows 99"; end
  end
  -- death_coil,if=!variable.pooling_for_gargoyle
  if S.DeathCoil:IsReady() and (not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil 101"; end
  end
end

local function Cooldowns()
  -- army_of_the_dead
  if S.ArmyoftheDead:IsCastable() then
    if HR.Cast(S.ArmyoftheDead, Settings.Unholy.GCDasOffGCD.ArmyoftheDead) then return "army_of_the_dead 113"; end
  end
  -- unholy_blight,if=variable.disable_aotd&(cooldown.apocalypse.ready&(debuff.festering_wound.stack>=4|rune>=3)|cooldown.apocalypse.remains)
  if S.UnholyBlight:IsCastable() and DisableAOTD() and (S.Apocalypse:CooldownUp() and (Target:DebuffStack(S.FesteringWoundDebuff) >= 4 or Player:Rune() >= 3) or bool(S.Apocalypse:CooldownRemains())) then
    if HR.Cast(S.UnholyBlight, nil, nil, not TargetIsInRange[10]) then return "unholy_blight 172"; end
  end
  -- dark_transformation,if=!raid_event.adds.exists&cooldown.unholy_blight.remains&(cooldown.apocalypse.ready&debuff.festering_wound.stack>=4|cooldown.apocalypse.remains)&(runeforge.deadliest_coil.equipped&!buff.dark_transformation.up|!runeforge.deadliest_coil.equipped)|!talent.unholy_blight.enabled|raid_event.adds.in>15&raid_event.adds.exists
  if S.DarkTransformation:IsCastable() and (bool(S.UnholyBlight:CooldownRemains()) and (S.Apocalypse:CooldownUp() and Target:DebuffStack(S.FesteringWoundDebuff) >= 4 or S.Apocalypse:CooldownUp()) and (DeadliestCoilEquipped and not S.DarkTransformation:BuffUp() or not DeadliestCoilEquipped) or not S.UnholyBlight:IsAvailable()) then
    if HR.Cast(S.DarkTransformation) then return "dark_transformation aoe"; end
  end
  -- apocalypse,if=debuff.festering_wound.stack>=4&((!talent.unholy_blight.enabled|talent.army_of_the_damned.enabled)|talent.unholy_blight.enabled&!talent.army_of_the_damned.enabled&dot.unholy_blight.remains)
  if S.Apocalypse:IsCastable() and (Target:DebuffStack(S.FesteringWoundDebuff) >= 4 and ((not S.UnholyBlight:IsAvailable() or S.ArmyoftheDamned:IsAvailable()) or S.UnholyBlight:IsAvailable() and not S.ArmyoftheDamned:IsAvailable() and Target:DebuffUp(S.UnholyBlightDebuff))) then
    if HR.Cast(S.Apocalypse) then return "apocalypse 115"; end
  end
  -- summon_gargoyle,if=runic_power.deficit<14
  if S.SummonGargoyle:IsCastable() and (Player:RunicPowerDeficit() < 14) then
    if HR.Cast(S.SummonGargoyle) then return "summon_gargoyle 123"; end
  end
  -- unholy_assault,if=active_enemies=1&pet.apoc_ghoul.active
  if S.UnholyAssault:IsCastable() and (EnemiesMeleeCount == 1 and S.Apocalypse:TimeSinceLastCast() <= 15) then
    if HR.Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault) then return "unholy_frenzy 139"; end
  end
  -- unholy_assault,if=active_enemies>=2&buff.dark_transformation.remains>12
  if S.UnholyAssault:IsCastable() and (EnemiesMeleeCount >= 2 and Pet:BuffRemains(S.DarkTransformation) > 12) then
    if HR.Cast(S.UnholyAssault, Settings.Unholy.GCDasOffGCD.UnholyAssault) then return "unholy_frenzy 141"; end
  end
  -- soul_reaper,target_if=target.health.pct<35&target.time_to_die>5
  if S.SoulReaper:IsCastable() then
    if Everyone.CastCycle(S.SoulReaper, Enemies30yd, EvaluateCycleSoulReaper) then return "soul_reaper 165" end
  end
  -- raise_dead,if=!pet.risen_ghoul.active
  if S.RaiseDead:IsCastable() then
    if HR.CastSuggested(S.RaiseDead) then return "raise_dead"; end
  end
  -- sacrificial_pact,if=active_enemies>=2
  if S.SacrificialPact:IsCastable() and (EnemiesMeleeCount >= 2 and S.RaiseDead:CooldownUp()) then
    if HR.Cast(S.SacrificialPact, Settings.Commons.GCDasOffGCD.SacrificialPact, nil, not TargetIsInRange[8]) then return "sacrificial pact cd 9"; end
  end
end

local function Racials()
  if (HR.CDsON()) then
    -- arcane_torrent,if=runic_power.deficit>65&pet.gargoyle.active&rune.deficit>=5
    if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 65 and S.SummonGargoyle:TimeSinceLastCast() <= 35 and Player:Rune() <= 1) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[8]) then return "arcane_torrent 248"; end
    end
    -- blood_fury,if=pet.gargoyle.active&talent.summon_gargoyle.enabled|buff.unholy_assault.up&talent.unholy_assault.enabled|pet.army_ghoul.active&talent.army_of_the_damned.enabled
    if S.BloodFury:IsCastable() and (S.SummonGargoyle:TimeSinceLastCast() <= 35 and S.SummonGargoyle:IsAvailable() or S.UnholyAssault:BuffUp() and S.UnholyAssault:IsAvailable() or ArmyoftheDead:TimeSinceLastCast() <= 30 and S.ArmyoftheDamned:IsAvailable()) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 252"; end
    end
    -- berserking,if=pet.gargoyle.active&talent.summon_gargoyle.enabled|buff.unholy_assault.up&talent.unholy_assault.enabled|pet.army_ghoul.active&talent.army_of_the_damned.enabled
    if S.Berserking:IsCastable() and (S.SummonGargoyle:TimeSinceLastCast() <= 35 and S.SummonGargoyle:IsAvailable() or S.UnholyAssault:BuffUp() and S.UnholyAssault:IsAvailable() or ArmyoftheDead:TimeSinceLastCast() <= 30 and S.ArmyoftheDamned:IsAvailable()) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 256"; end
    end
    -- lights_judgment,if=buff.unholy_strength.up
    if S.LightsJudgment:IsCastable() and Player:BuffUp(S.UnholyStrengthBuff) then
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[40]) then return "lights_judgment 257"; end
    end
    -- ancestral_call,if=pet.gargoyle.active&talent.summon_gargoyle.enabled|buff.unholy_assault.up&talent.unholy_assault.enabled|pet.army_ghoul.active&talent.army_of_the_damned.enabled
    if S.AncestralCall:IsCastable() and (S.SummonGargoyle:TimeSinceLastCast() <= 35 and S.SummonGargoyle:IsAvailable() or S.UnholyAssault:BuffUp() and S.UnholyAssault:IsAvailable() or S.ArmyoftheDead:TimeSinceLastCast() <= 30 and S.ArmyoftheDamned:IsAvailable()) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 258"; end
    end
    -- arcane_pulse,if=active_enemies>=2|(rune.deficit>=5&runic_power.deficit>=60)
    if S.ArcanePulse:IsCastable() and (EnemiesMeleeCount >= 2 or (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
      if HR.Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[8]) then return "arcane_pulse 259"; end
    end
    -- fireblood, if=pet.gargoyle.active&talent.summon_gargoyle.enabled|buff.unholy_assault.up&talent.unholy_assault.enabled|pet.army_ghoul.active&talent.army_of_the_damned.enabled
    if S.Fireblood:IsCastable() and (S.SummonGargoyle:TimeSinceLastCast() <= 35 and S.SummonGargoyle:IsAvailable() or S.UnholyAssault:BuffUp() and S.UnholyAssault:IsAvailable() or S.ArmyoftheDead:TimeSinceLastCast() <= 30 and S.ArmyoftheDamned:IsAvailable()) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 260"; end
    end
    -- bag_of_tricks,if=buff.unholy_strength.up&active_enemies=1
    if S.BagofTricks:IsCastable() and Player:BuffUp(S.UnholyStrengthBuff) and EnemiesMeleeCount == 1 then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not TargetIsInRange[30]) then return "bag_of_tricks 260.5"; end
    end
  end
end

local function Generic()
  -- death_coil,if=buff.sudden_doom.react&rune.time_to_4>gcd&!variable.pooling_for_gargoyle|pet.gargoyle.active
  if S.DeathCoil:IsUsable() and (Player:BuffUp(S.SuddenDoomBuff) and Player:RuneTimeToX(4) > Player:GCD() and not bool(VarPoolingForGargoyle) or S.SummonGargoyle:TimeSinceLastCast() <= 35) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil 174"; end
  end
  -- Manually added: Multiple target Epidemic in place of below Death Coil
  if S.Epidemic:IsReady() and (Player:RunicPowerDeficit() < 14 and Player:RuneTimeToX(4) > Player:GCD() and not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:AuraActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic 173"; end
  end
  -- death_coil,if=runic_power.deficit<14&rune.time_to_4>gcd&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and (Player:RunicPowerDeficit() < 14 and Player:RuneTimeToX(4) > Player:GCD() and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil 180"; end
  end
  -- defile
  if S.Defile:IsCastable() then
    if HR.Cast(S.Defile, Settings.Unholy.GCDasOffGCD.Defile) then return "defile"; end
  end
  -- scourge_strike,if=debuff.festering_wound.up&(!talent.unholy_blight.enabled|talent.army_of_the_damned.enabled)&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&variable.disable_aotd
  if S.ScourgeStrike:IsCastable() and (Target:DebuffUp(S.FesteringWoundDebuff) and (not S.UnholyBlight:IsAvailable() or S.ArmyoftheDamned:IsAvailable()) and (S.Apocalypse:CooldownRemains() > 5 or Target:DebuffStack(S.FesteringWoundDebuff) > 4) and DisableAOTD()) then
    if HR.Cast(S.ScourgeStrike, nil, nil, not TargetIsInRange[8]) then return "scourge_strike 198"; end
  end
  -- scourge_strike,if=debuff.festering_wound.up&talent.unholy_blight.enabled&!talent.army_of_the_damned.enabled&(((cooldown.unholy_blight.remains>5|cooldown.apocalypse.remains>40)&(cooldown.apocalypse.remains|cooldown.apocalypse.ready&!dot.unholy_blight.remains))|debuff.festering_wound.stack>4)&variable.disable_aotd
  if S.ScourgeStrike:IsCastable() and (Target:DebuffUp(S.FesteringWoundDebuff) and S.UnholyBlight:IsAvailable() and not S.ArmyoftheDamned:IsAvailable() and (((S.UnholyBlight:CooldownRemains() > 5 or S.Apocalypse:CooldownRemains() > 40) and (bool(S.Apocalypse:CooldownRemains()) or S.Apocalypse:CooldownUp() and not Target:DebuffUp(S.UnholyBlightDebuff))) or Target:DebuffStack(S.FesteringWoundDebuff) >4) and DisableAOTD()) then
    if HR.Cast(S.ScourgeStrike, nil, nil, not TargetIsInRange[8]) then return "scourge_strike 199"; end
  end
  -- clawing_shadows,if=debuff.festering_wound.up&(!talent.unholy_blight.enabled|talent.army_of_the_damned.enabled)&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&variable.disable_aotd
  if S.ClawingShadows:IsCastable() and (Target:DebuffUp(S.FesteringWoundDebuff) and (not S.UnholyBlight:IsAvailable() or S.ArmyoftheDamned:IsAvailable()) and (S.Apocalypse:CooldownRemains() > 5 or Target:DebuffStack(S.FesteringWoundDebuff) > 4) and DisableAOTD()) then
    if HR.Cast(S.ClawingShadows, nil, nil, not TargetIsInRange[30]) then return "clawing_shadows 208"; end
  end
  -- clawing_shadows,if=debuff.festering_wound.up&talent.unholy_blight.enabled&!talent.army_of_the_damned.enabled&(((cooldown.unholy_blight.remains>5|cooldown.apocalypse.remains>40)&(cooldown.apocalypse.remains|cooldown.apocalypse.ready&!dot.unholy_blight.remains))|debuff.festering_wound.stack>4)&variable.disable_aotd
  if S.ClawingShadows:IsCastable() and (Target:DebuffUp(S.FesteringWoundDebuff) and S.UnholyBlight:IsAvailable() and not S.ArmyoftheDamned:IsAvailable() and (((S.UnholyBlight:CooldownRemains() > 5 or S.Apocalypse:CooldownRemains() > 40) and (bool(S.Apocalypse:CooldownRemains()) or S.Apocalypse:CooldownUp() and not Target:DebuffUp(S.UnholyBlightDebuff))) or Target:DebuffStack(S.FesteringWoundDebuff) >4) and DisableAOTD()) then
    if HR.Cast(S.ClawingShadows, nil, nil, not TargetIsInRange[30]) then return "clawing_shadows 209"; end
  end
    -- Manually added: Multiple target Epidemic if close to capping RP
  if S.Epidemic:IsReady() and (Player:RunicPowerDeficit() < 20 and not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:AuraActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[30]) then return "epidemic 173"; end
  end
  -- death_coil,if=runic_power.deficit<20&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and (Player:RunicPowerDeficit() < 20 and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil 218"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<4&((cooldown.apocalypse.remains<3&((!talent.unholy_blight.enabled|talent.army_of_the_damned.enabled)|((talent.unholy_blight.enabled&!talent.army_of_the_damned.enabled)&((cooldown.unholy_blight.remains<3|cooldown.apocalypse.remains>40)|dot.unholy_blight.remains))))|debuff.festering_wound.stack<1)&variable.disable_aotd
  if S.FesteringStrike:IsCastable() and (Target:DebuffStack(S.FesteringWoundDebuff) < 4 and ((S.Apocalypse:CooldownRemains() < 3 and ((not S.UnholyBlight:IsAvailable() or S.ArmyoftheDamned:IsAvailable()) or ((S.UnholyBlight:IsAvailable() and not S.ArmyoftheDamned:IsAvailable()) and ((S.UnholyBlight:CooldownRemains() < 3 or S.Apocalypse:CooldownRemains() > 40) or Target:DebuffUp(S.UnholyBlightDebuff))))) or Target:DebuffStack(S.FesteringWoundDebuff) < 1) and DisableAOTD()) then
    if HR.Cast(S.FesteringStrike, nil, nil, not TargetIsInRange[8]) then return "festering_strike 222"; end
  end
  -- Manually added: Multiple target Epidemic filler to burn RP
  if S.Epidemic:IsReady() and (not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:AuraActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, not TargetIsInRange[100]) then return "epidemic 173"; end
  end
  -- death_coil,if=!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsable() and (not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, not TargetIsInRange[30]) then return "death_coil 236"; end
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
    if S.DeathStrike:IsReady("Melee") and not no_heal then
      if HR.Cast(S.DeathStrike) then return "death_strike low hp or proc"; end
    end
    -- auto_attack
    -- variable,name=pooling_for_gargoyle,value=cooldown.summon_gargoyle.remains<5&talent.summon_gargoyle.enabled
    if (true) then
      VarPoolingForGargoyle = num(S.SummonGargoyle:CooldownRemains() < 5 and S.SummonGargoyle:IsAvailable())
    end

    --Settings.Commons.UseTrinkets

    -- outbreak,target_if=dot.virulent_plague.remains<=gcd
    if S.Outbreak:IsCastable() then
      if Everyone.CastCycle(S.Outbreak, Enemies30yd, EvaluateCycleOutbreak) then return "outbreak 307" end
    end
    -- call_action_list,name=cooldowns
    if (true) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- racials
    if (true) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=aoe,if=active_enemies>=2
    if (EnemiesMeleeCount >= 2) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=generic
    if (true) then
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
