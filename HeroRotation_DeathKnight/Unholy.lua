--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
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
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.DeathKnight then Spell.DeathKnight = {} end
Spell.DeathKnight.Unholy = {
  RaiseDead                             = Spell(46584),
  SacrificialPact                       = Spell(327574),
  ArmyoftheDead                         = Spell(42650),
  DeathandDecay                         = Spell(43265),
  DeathandDecayBuff                     = Spell(188290),
  Apocalypse                            = Spell(275699),
  Defile                                = Spell(152280),
  Epidemic                              = Spell(207317),
  DeathCoil                             = Spell(47541),
  ScourgeStrike                         = Spell(55090),
  ClawingShadows                        = Spell(207311),
  FesteringStrike                       = Spell(85948),
  FesteringWoundDebuff                  = Spell(194310),
  BurstingSores                         = Spell(207264),
  SuddenDoomBuff                        = Spell(81340),
  UnholyFrenzyBuff                      = Spell(207289),
  DarkTransformation                    = Spell(63560),
  SummonGargoyle                        = MultiSpell(49206, 207349),
  UnholyFrenzy                          = Spell(207289),
  MagusoftheDead                        = Spell(288417),
  SoulReaper                            = Spell(130736),
  UnholyBlight                          = Spell(115989),
  Pestilence                            = Spell(277234),
  ArcaneTorrent                         = Spell(50613),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  LightsJudgment                        = Spell(255647),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  ArcanePulse                           = Spell(260364),
  Fireblood                             = Spell(265221),
  UnholyStrengthBuff                    = Spell(53365),
  FestermightBuff                       = Spell(274373),
  ArmyoftheDamned                       = Spell(276837),
  Outbreak                              = Spell(77575),
  VirulentPlagueDebuff                  = Spell(191587),
  DeathStrike                           = Spell(49998),
  DeathStrikeBuff                       = Spell(101568),
  MindFreeze                            = Spell(47528),
  PoolResources                         = Spell(9999000010)
};
local S = Spell.DeathKnight.Unholy;

-- Items
if not Item.DeathKnight then Item.DeathKnight = {} end
Item.DeathKnight.Unholy = {
  -- Potions/Trinkets
  -- "Other On Use"
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
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Unholy = HR.GUISettings.APL.DeathKnight.Unholy
};

-- Variables
local VarPoolingForGargoyle = 0;

HL:RegisterForEvent(function()
  VarPoolingForGargoyle = 0
end, "PLAYER_REGEN_ENABLED")

local EnemyRanges = {30, 8}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function DeathStrikeHeal()
  return (Settings.General.SoloMode and (Player:HealthPercentage() < Settings.Commons.UseDeathStrikeHP or Player:HealthPercentage() < Settings.Commons.UseDarkSuccorHP and Player:BuffP(S.DeathStrikeBuff)))
end

local function DisableAOTD()
  return (S.ArmyoftheDead:CooldownRemainsP() > 5 or Settings.Unholy.AotDOff)
end

local function EvaluateCycleFesteringStrike40(TargetUnit)
  return (TargetUnit:DebuffStackP(S.FesteringWoundDebuff) <= 2 and not S.DeathandDecay:CooldownUpP() and S.Apocalypse:CooldownRemainsP() > 5 and DisableAOTD())
end

local function EvaluateCycleSoulReaper163(TargetUnit)
  return (TargetUnit:TimeToDie() < 8 and TargetUnit:TimeToDie() > 4)
end

local function EvaluateCycleOutbreak303(TargetUnit)
  return TargetUnit:DebuffRemainsP(S.VirulentPlagueDebuff) <= Player:GCD()
end

local function EvaluateCycleScourgeClaw90(TargetUnit)
  return (DisableAOTD() and (S.Apocalypse:CooldownRemainsP() > 5 and TargetUnit:DebuffP(S.FesteringWoundDebuff) or TargetUnit:DebuffStackP(S.FesteringWoundDebuff) > 4) and (TargetUnit:TimeToDie() < S.DeathandDecay:CooldownRemainsP() + 10 or TargetUnit:TimeToDie() > S.Apocalypse:CooldownRemainsP()))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  -- raise_dead
  if S.RaiseDead:IsCastableP() then
    if HR.CastSuggested(S.RaiseDead) then return "raise_dead 6"; end
  end
  if Everyone.TargetIsValid() then
    -- army_of_the_dead,precombat_time=2
    if S.ArmyoftheDead:IsCastableP() then
      if HR.Cast(S.ArmyoftheDead, Settings.Unholy.GCDasOffGCD.ArmyoftheDead) then return "army_of_the_dead 8"; end
    end
  end
end

local function Aoe()
  -- death_and_decay,if=cooldown.apocalypse.remains
  if S.DeathandDecay:IsCastableP() and (not S.Apocalypse:CooldownUpP()) then
    if HR.Cast(S.DeathandDecay, Settings.Unholy.GCDasOffGCD.DeathandDecay) then return "death_and_decay 10"; end
  end
  -- defile,if=cooldown.apocalypse.remains
  if S.Defile:IsCastableP() and (not S.Apocalypse:CooldownUpP()) then
    if HR.Cast(S.Defile) then return "defile 14"; end
  end
  -- epidemic,if=death_and_decay.ticking&runic_power.deficit<14&!talent.bursting_sores.enabled&!variable.pooling_for_gargoyle
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReadyP() and (Player:BuffP(S.DeathandDecayBuff) and Player:RunicPowerDeficit() < 14 and not S.BurstingSores:IsAvailable() and not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:ActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, 100) then return "epidemic 16"; end
  end
  -- epidemic,if=death_and_decay.ticking&(!death_knight.fwounded_targets&talent.bursting_sores.enabled)&!variable.pooling_for_gargoyle
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReadyP() and (Player:BuffP(S.DeathandDecayBuff) and (S.FesteringWoundDebuff:ActiveCount() == 0 and S.BurstingSores:IsAvailable()) and not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:ActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, 100) then return "epidemic 18"; end
  end
  -- scourge_strike,if=death_and_decay.ticking&cooldown.apocalypse.remains
  if S.ScourgeStrike:IsCastableP() and (Player:BuffP(S.DeathandDecayBuff) and not S.Apocalypse:CooldownUpP()) then
    if HR.Cast(S.ScourgeStrike, nil, nil, "Melee") then return "scourge_strike 24"; end
  end
  -- clawing_shadows,if=death_and_decay.ticking&cooldown.apocalypse.remains
  if S.ClawingShadows:IsCastableP() and (Player:BuffP(S.DeathandDecayBuff) and not S.Apocalypse:CooldownUpP()) then
    if HR.Cast(S.ClawingShadows, nil, nil, 30) then return "clawing_shadows 28"; end
  end
  -- epidemic,if=!variable.pooling_for_gargoyle
  -- Added check to ensure at least 2 targets have Plague
  if S.Epidemic:IsReadyP() and (not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:ActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, 100) then return "epidemic 32"; end
  end
  -- festering_strike,target_if=debuff.festering_wound.stack<=2&cooldown.death_and_decay.remains&cooldown.apocalypse.remains>5&(cooldown.army_of_the_dead.remains>5|death_knight.disable_aotd)
  if S.FesteringStrike:IsCastableP() then
    if HR.CastCycle(S.FesteringStrike, 30, EvaluateCycleFesteringStrike40) then return "festering_strike 46" end
  end
  -- death_coil,if=buff.sudden_doom.react&rune.time_to_4>gcd
  if S.DeathCoil:IsUsableP() and (Player:BuffP(S.SuddenDoomBuff) and Player:RuneTimeToX(4) > Player:GCD()) then
    if HR.Cast(S.DeathCoil, nil, nil, 30) then return "death_coil 53"; end
  end
  -- death_coil,if=buff.sudden_doom.react&!variable.pooling_for_gargoyle|pet.gargoyle.active
  if S.DeathCoil:IsUsableP() and (Player:BuffP(S.SuddenDoomBuff) and not bool(VarPoolingForGargoyle) or S.SummonGargoyle:TimeSinceLastCast() <= 35) then
    if HR.Cast(S.DeathCoil, nil, nil, 30) then return "death_coil 57"; end
  end
  -- death_coil,if=runic_power.deficit<14&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsableP() and (Player:RunicPowerDeficit() < 14 and (S.Apocalypse:CooldownRemainsP() > 5 or Target:DebuffStackP(S.FesteringWoundDebuff) > 4) and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, 30) then return "death_coil 63"; end
  end
  -- scourge_strike,target_if=((cooldown.army_of_the_dead.remains>5|death_knight.disable_aotd)&(cooldown.apocalypse.remains>5&debuff.festering_wound.stack>0|debuff.festering_wound.stack>4)&(target.1.time_to_die<cooldown.death_and_decay.remains+10|target.1.time_to_die>cooldown.apocalypse.remains))
  if S.ScourgeStrike:IsCastableP() then
    if HR.CastCycle(S.ScourgeStrike, 8, EvaluateCycleScourgeClaw90) then return "scourge_strike 71"; end
  end
  -- clawing_shadows,target_if=((cooldown.army_of_the_dead.remains>5|death_knight.disable_aotd)&(cooldown.apocalypse.remains>5&debuff.festering_wound.stack>0|debuff.festering_wound.stack>4)&(target.1.time_to_die<cooldown.death_and_decay.remains+10|target.1.time_to_die>cooldown.apocalypse.remains))
  if S.ClawingShadows:IsCastableP() then
    if HR.CastCycle(S.ClawingShadows, 30, EvaluateCycleScourgeClaw90) then return "clawing_shadows 81"; end
  end
  -- death_coil,if=runic_power.deficit<20&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsableP() and (Player:RunicPowerDeficit() < 20 and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, 30) then return "death_coil 91"; end
  end
  -- festering_strike,if=((((debuff.festering_wound.stack<4&!buff.unholy_frenzy.up)|debuff.festering_wound.stack<3)&cooldown.apocalypse.remains<3)|debuff.festering_wound.stack<1)&(cooldown.army_of_the_dead.remains>5|death_knight.disable_aotd)
  if S.FesteringStrike:IsCastableP() and (((((Target:DebuffStackP(S.FesteringWoundDebuff) < 4 and Player:BuffDownP(S.UnholyFrenzyBuff)) or Target:DebuffStackP(S.FesteringWoundDebuff) < 3) and S.Apocalypse:CooldownRemainsP() < 3) or Target:DebuffStackP(S.FesteringWoundDebuff) < 1) and DisableAOTD()) then
    if HR.Cast(S.FesteringStrike, nil, nil, "Melee") then return "festering_strike 95"; end
  end
  -- scourge_strike,if=death_and_decay.ticking
  if S.ScourgeStrike:IsCastableP() and (Player:BuffP(S.DeathandDecayBuff)) then
    if HR.Cast(S.ScourgeStrike, nil, nil, "Melee") then return "scourge_strike 97"; end
  end
  -- clawing_shadows,if=death_and_decay.ticking
  if S.ClawingShadows:IsCastableP() and (Player:BuffP(S.DeathandDecayBuff)) then
    if HR.Cast(S.ClawingShadows, nil, nil, 30) then return "clawing_shadows 99"; end
  end
  -- death_coil,if=!variable.pooling_for_gargoyle
  if S.DeathCoil:IsReadyP() and (not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, 30) then return "death_coil 101"; end
  end
end

local function Cooldowns()
  -- army_of_the_dead
  if S.ArmyoftheDead:IsCastableP() then
    if HR.Cast(S.ArmyoftheDead, Settings.Unholy.GCDasOffGCD.ArmyoftheDead) then return "army_of_the_dead 113"; end
  end
  -- unholy_blight,if=cooldown.apocalypse.ready&debuff.festering_wound.stack>=4|cooldown.apocalypse.remains
  if S.UnholyBlight:IsCastableP() and (S.Apocalypse:CooldownUpP() and Target:DebuffStackP(FesteringWoundDebuff) >= 4 or bool(S.Apocalypse:CooldownRemainsP())) then
    if HR.Cast(S.UnholyBlight, nil, nil, 10) then return "unholy_blight 172"; end
  end
  -- apocalypse,if=debuff.festering_wound.stack>=4
  if S.Apocalypse:IsCastableP() and (Target:DebuffStackP(S.FesteringWoundDebuff) >= 4) then
    if HR.Cast(S.Apocalypse) then return "apocalypse 115"; end
  end
  -- dark_transformation,if=!raid_event.adds.exists|raid_event.adds.in>15
  if S.DarkTransformation:IsCastableP() and not Cache.EnemiesCount[8] > 1 then
    if HR.Cast(S.DarkTransformation, Settings.Unholy.GCDasOffGCD.DarkTransformation) then return "dark_transformation 119"; end
  end
  -- summon_gargoyle,if=runic_power.deficit<14
  if S.SummonGargoyle:IsCastableP() and (Player:RunicPowerDeficit() < 14) then
    if HR.Cast(S.SummonGargoyle) then return "summon_gargoyle 123"; end
  end
  -- unholy_frenzy,if=active_enemies=1&pet.apoc_ghoul.active
  if S.UnholyFrenzy:IsCastableP() and (Cache.EnemiesCount[8] == 1 and S.Apocalypse:TimeSinceLastCast() <= 15) then
    if HR.Cast(S.UnholyFrenzy, Settings.Unholy.GCDasOffGCD.UnholyFrenzy) then return "unholy_frenzy 139"; end
  end
  -- unholy_frenzy,if=active_enemies>=2&((cooldown.death_and_decay.remains<=gcd&!talent.defile.enabled)|(cooldown.defile.remains<=gcd&talent.defile.enabled))
  if S.UnholyFrenzy:IsCastableP() and (Cache.EnemiesCount[8] >= 2 and ((S.DeathandDecay:CooldownRemainsP() <= Player:GCD() and not S.Defile:IsAvailable()) or (S.Defile:CooldownRemainsP() <= Player:GCD() and S.Defile:IsAvailable()))) then
    if HR.Cast(S.UnholyFrenzy, Settings.Unholy.GCDasOffGCD.UnholyFrenzy) then return "unholy_frenzy 141"; end
  end
  -- soul_reaper,target_if=target.time_to_die<8&target.time_to_die>4
  if S.SoulReaper:IsCastableP() then
    if HR.CastCycle(S.SoulReaper, 30, EvaluateCycleSoulReaper163) then return "soul_reaper 165" end
  end
  -- soul_reaper,if=(!raid_event.adds.exists|raid_event.adds.in>20)&rune<=(1-buff.unholy_frenzy.up)
  if S.SoulReaper:IsCastableP() and ((not (Cache.EnemiesCount[8] > 1)) and Player:Rune() <= (1 - num(Player:BuffP(S.UnholyFrenzyBuff)))) then
    if HR.Cast(S.SoulReaper, nil, nil, "Melee") then return "soul_reaper 166"; end
  end
  -- raise_dead,if=!pet.risen_ghoul.active
  if S.RaiseDead:IsCastableP() then
    if HR.CastSuggested(S.RaiseDead) then return "raise_dead"; end
  end
  -- sacrificial_pact,if=active_enemies>=2
  if S.SacrificialPact:IsCastableP() and (Cache.EnemiesCount[8] >= 2 and S.RaiseDead:CooldownUpP()) then
    if HR.Cast(S.SacrificialPact, Settings.Commons.GCDasOffGCD.SacrificialPact, nil, 8) then return "sacrificial pact cd 9"; end
  end
end

local function Racials()
  if (HR.CDsON()) then
    -- arcane_torrent,if=runic_power.deficit>65&(pet.gargoyle.active|!talent.summon_gargoyle.enabled)&rune.deficit>=5
    if S.ArcaneTorrent:IsCastableP() and (Player:RunicPowerDeficit() > 65 and (S.SummonGargoyle:TimeSinceLastCast() <= 35 or not S.SummonGargoyle:IsAvailable()) and Player:Rune() <= 1) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_torrent 248"; end
    end
    -- blood_fury,if=pet.gargoyle.active|!talent.summon_gargoyle.enabled
    if S.BloodFury:IsCastableP() and (S.SummonGargoyle:TimeSinceLastCast() <= 35 or not S.SummonGargoyle:IsAvailable()) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 252"; end
    end
    -- berserking,if=buff.unholy_frenzy.up|pet.gargoyle.active|(talent.army_of_the_damned.enabled&pet.apoc_ghoul.active)
    if S.Berserking:IsCastableP() and (Player:BuffP(S.UnholyFrenzyBuff) or S.SummonGargoyle:TimeSinceLastCast() <= 35 or (S.ArmyoftheDamned:IsAvailable() and S.Apocalypse:TimeSinceLastCast() <= 15)) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 256"; end
    end
    -- lights_judgment,if=(buff.unholy_strength.up&buff.festermight.remains<=5)|active_enemies>=2&(buff.unholy_strength.up|buff.festermight.remains<=5)
    if S.LightsJudgment:IsCastableP() and ((Player:BuffP(S.UnholyStrengthBuff) and Player:BuffRemainsP(S.FestermightBuff) <= 5) or Cache.EnemiesCount[8] >= 2 and (Player:BuffP(S.UnholyStrengthBuff) or Player:BuffRemainsP(S.FestermightBuff) <= 5)) then
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 257"; end
    end
    -- ancestral_call,if=(pet.gargoyle.active&talent.summon_gargoyle.enabled)|pet.apoc_ghoul.active
    if S.AncestralCall:IsCastableP() and ((S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:TimeSinceLastCast() <= 35) or S.Apocalypse:TimeSinceLastCast() <= 15) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 258"; end
    end
    -- arcane_pulse,if=active_enemies>=2|(rune.deficit>=5&runic_power.deficit>=60)
    if S.ArcanePulse:IsCastableP() and (Cache.EnemiesCount[8] >= 2 or (Player:Rune() <= 1 and Player:RunicPowerDeficit() >= 60)) then
      if HR.Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, 8) then return "arcane_pulse 259"; end
    end
    -- fireblood,if=(pet.gargoyle.active&talent.summon_gargoyle.enabled)|pet.apoc_ghoul.active
    if S.Fireblood:IsCastableP() and ((S.SummonGargoyle:IsAvailable() and S.SummonGargoyle:TimeSinceLastCast() <= 35) or S.Apocalypse:TimeSinceLastCast() <= 15) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 260"; end
    end
    -- bag_of_tricks,if=buff.unholy_strength.up&active_enemies=1|buff.festermight.remains<gcd&active_enemies=1
    if S.BagofTricks:IsCastableP() and (Player:BuffP(S.UnholyStrengthBuff) and Cache.EnemiesCount[8] == 1 or Player:BuffRemainsP(S.FestermightBuff) < Player:GCD() and Cache.EnemiesCount[8] == 1) then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 260.5"; end
    end
  end
end

local function Generic()
  -- death_coil,if=if=buff.sudden_doom.react&rune.time_to_4>gcd&!variable.pooling_for_gargoyle|pet.gargoyle.active
  if S.DeathCoil:IsUsableP() and (Player:BuffP(S.SuddenDoomBuff) and Player:RuneTimeToX(4) > Player:GCD() and not bool(VarPoolingForGargoyle) or S.SummonGargoyle:TimeSinceLastCast() <= 35) then
    if HR.Cast(S.DeathCoil, nil, nil, 30) then return "death_coil 174"; end
  end
  -- Manually added: Multiple target Epidemic in place of below Death Coil
  if S.Epidemic:IsReadyP() and (Player:RunicPowerDeficit() < 14 and Player:RuneTimeToX(4) > Player:GCD() and not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:ActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, 100) then return "epidemic 173"; end
  end
  -- death_coil,if=runic_power.deficit<14&rune.time_to_4>gcd&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsableP() and (Player:RunicPowerDeficit() < 14 and Player:RuneTimeToX(4) > Player:GCD() and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, 30) then return "death_coil 180"; end
  end
  -- scourge_strike,if=debuff.festering_wound.up&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&variable.disable_aotd
  if S.ScourgeStrike:IsCastableP() and (Target:DebuffP(S.FesteringWoundDebuff) and (S.Apocalypse:CooldownRemainsP() > 5 or Target:DebuffStackP(S.FesteringWoundDebuff) > 4) and DisableAOTD()) then
    if HR.Cast(S.ScourgeStrike, nil, nil, "Melee") then return "scourge_strike 198"; end
  end
  -- clawing_shadows,if=debuff.festering_wound.up&(cooldown.apocalypse.remains>5|debuff.festering_wound.stack>4)&variable.disable_aotd
  if S.ClawingShadows:IsCastableP() and (Target:DebuffP(S.FesteringWoundDebuff) and (S.Apocalypse:CooldownRemainsP() > 5 or Target:DebuffStackP(S.FesteringWoundDebuff) > 4) and DisableAOTD()) then
    if HR.Cast(S.ClawingShadows, nil, nil, 30) then return "clawing_shadows 208"; end
  end
  -- Manually added: Multiple target Epidemic if close to capping RP
  if S.Epidemic:IsReadyP() and (Player:RunicPowerDeficit() < 20 and not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:ActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, 100) then return "epidemic 173"; end
  end
  -- death_coil,if=runic_power.deficit<20&!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsableP() and (Player:RunicPowerDeficit() < 20 and not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, 30) then return "death_coil 218"; end
  end
  -- festering_strike,if=debuff.festering_wound.stack<4&cooldown.apocalypse.remains<3|debuff.festering_wound.stack<1&variable.disable_aotd
  if S.FesteringStrike:IsCastableP() and (Target:DebuffStackP(S.FesteringWoundDebuff) < 4 and S.Apocalypse:CooldownRemainsP() < 3 or Target:DebuffStackP(S.FesteringWoundDebuff) < 1 and DisableAOTD()) then
    if HR.Cast(S.FesteringStrike, nil, nil, "Melee") then return "festering_strike 222"; end
  end
  -- Manually added: Multiple target Epidemic filler to burn RP
  if S.Epidemic:IsReadyP() and (not bool(VarPoolingForGargoyle) and S.VirulentPlagueDebuff:ActiveCount() > 1) then
    if HR.Cast(S.Epidemic, Settings.Unholy.GCDasOffGCD.Epidemic, nil, 100) then return "epidemic 173"; end
  end
  -- death_coil,if=!variable.pooling_for_gargoyle
  if S.DeathCoil:IsUsableP() and (not bool(VarPoolingForGargoyle)) then
    if HR.Cast(S.DeathCoil, nil, nil, 30) then return "death_coil 236"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  no_heal = not DeathStrikeHeal()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, false); if ShouldReturn then return ShouldReturn; end
    -- use DeathStrike on low HP or with proc in Solo Mode
    if S.DeathStrike:IsReadyP("Melee") and not no_heal then
      if HR.Cast(S.DeathStrike) then return "death_strike low hp or proc"; end
    end
    -- auto_attack
    -- variable,name=pooling_for_gargoyle,value=cooldown.summon_gargoyle.remains<5&talent.summon_gargoyle.enabled
    if (true) then
      VarPoolingForGargoyle = num(S.SummonGargoyle:CooldownRemainsP() < 5 and S.SummonGargoyle:IsAvailable())
    end

    --Settings.Commons.UseTrinkets

    -- outbreak,target_if=dot.virulent_plague.remains<=gcd
    if S.Outbreak:IsCastableP() then
      if HR.CastCycle(S.Outbreak, 30, EvaluateCycleOutbreak303) then return "outbreak 307" end
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
    if (Cache.EnemiesCount[8] >= 2) then
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
  HL.RegisterNucleusAbility(152280, 8, 6)               -- Defile
  HL.RegisterNucleusAbility(115989, 8, 6)               -- Unholy Blight
  HL.RegisterNucleusAbility(43265, 8, 6)                -- Death and Decay
end

HR.SetAPL(252, APL, Init)
