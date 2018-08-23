--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL     = HeroLib
local Cache  = HeroCache
local Unit   = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = HL.Spell
local Item   = HL.Item
-- HeroRotation
local HR     = HeroRotation

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Warrior then Spell.Warrior = {} end
Spell.Warrior.Arms = {
  Rend                                  = Spell(772),
  RendDebuff                            = Spell(772),
  ColossusSmashDebuff                   = Spell(208086),
  Skullsplitter                         = Spell(260643),
  DeadlyCalm                            = Spell(262228),
  DeadlyCalmBuff                        = Spell(262228),
  Bladestorm                            = Spell(227847),
  ColossusSmash                         = Spell(167105),
  Warbreaker                            = Spell(262161),
  HeroicLeap                            = Spell(6544),
  Ravager                               = Spell(152277),
  MortalStrike                          = Spell(12294),
  OverpowerBuff                         = Spell(7384),
  Dreadnaught                           = Spell(262150),
  Overpower                             = Spell(7384),
  Execute                               = Spell(163201),
  SuddenDeathBuff                       = Spell(52437),
  StoneHeartBuff                        = Spell(225947),
  SweepingStrikesBuff                   = Spell(260708),
  Cleave                                = Spell(845),
  DeepWoundsDebuff                      = Spell(262115),
  SweepingStrikes                       = Spell(260708),
  Whirlwind                             = Spell(1680),
  FervorofBattle                        = Spell(202316),
  Slam                                  = Spell(1464),
  Charge                                = Spell(100),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Avatar                                = Spell(107574),
  Massacre                              = Spell(281001)
};
local S = Spell.Warrior.Arms;

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Arms = {
  ProlongedPower                   = Item(142117),
  WeightoftheEarth                 = Item(137077),
  ArchavonsHeavyHand               = Item(137060)
};
local I = Item.Warrior.Arms;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Arms = HR.GUISettings.APL.Warrior.Arms
};

-- Variables

local EnemyRanges = {8}
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

S.ExecuteDefault    = Spell(163201)
S.ExecuteMassacre   = Spell(281000)

local function UpdateExecuteID()
    S.Execute = S.Massacre:IsAvailable() and S.ExecuteMassacre or S.ExecuteDefault
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Execute, FiveTarget, SingleTarget
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  UpdateExecuteID()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.ProlongedPower) then return ""; end
    end
  end
  Execute = function()
    -- rend,if=remains<=duration*0.3&debuff.colossus_smash.down
    if S.Rend:IsCastableP() and (Target:DebuffRemainsP(S.RendDebuff) <= S.RendDebuff:BaseDuration() * 0.3 and Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Rend) then return ""; end
    end
    -- skullsplitter,if=rage<70&((cooldown.deadly_calm.remains>3&!buff.deadly_calm.up)|!talent.deadly_calm.enabled)
    if S.Skullsplitter:IsCastableP() and (Player:Rage() < 70 and ((S.DeadlyCalm:CooldownRemainsP() > 3 and not Player:BuffP(S.DeadlyCalmBuff)) or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Skullsplitter) then return ""; end
    end
    -- deadly_calm,if=cooldown.bladestorm.remains>6&((cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2))|(equipped.weight_of_the_earth&cooldown.heroic_leap.remains<2))
    if S.DeadlyCalm:IsCastableP() and (S.Bladestorm:CooldownRemainsP() > 6 and ((S.ColossusSmash:CooldownRemainsP() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 2)) or (I.WeightoftheEarth:IsEquipped() and S.HeroicLeap:CooldownRemainsP() < 2))) then
      if HR.Cast(S.DeadlyCalm) then return ""; end
    end
    -- colossus_smash,if=debuff.colossus_smash.down
    if S.ColossusSmash:IsCastableP() and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.ColossusSmash) then return ""; end
    end
    -- warbreaker,if=debuff.colossus_smash.down
    if S.Warbreaker:IsCastableP() and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Warbreaker) then return ""; end
    end
    -- heroic_leap,if=equipped.weight_of_the_earth&debuff.colossus_smash.down&((cooldown.colossus_smash.remains>8&!prev_gcd.1.colossus_smash)|(talent.warbreaker.enabled&cooldown.warbreaker.remains>8&!prev_gcd.1.warbreaker))
    if S.HeroicLeap:IsCastableP() and (I.WeightoftheEarth:IsEquipped() and Target:DebuffDownP(S.ColossusSmashDebuff) and ((S.ColossusSmash:CooldownRemainsP() > 8 and not Player:PrevGCDP(1, S.ColossusSmash)) or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() > 8 and not Player:PrevGCDP(1, S.Warbreaker)))) then
      if HR.Cast(S.HeroicLeap) then return ""; end
    end
    -- bladestorm,if=debuff.colossus_smash.remains>4.5&rage<70&(!buff.deadly_calm.up|!talent.deadly_calm.enabled)
    if S.Bladestorm:IsCastableP() and (Target:DebuffRemainsP(S.ColossusSmashDebuff) > 4.5 and Player:Rage() < 70 and (not Player:BuffP(S.DeadlyCalmBuff) or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Bladestorm) then return ""; end
    end
    -- ravager,if=debuff.colossus_smash.up&(cooldown.deadly_calm.remains>6|!talent.deadly_calm.enabled)
    if S.Ravager:IsCastableP() and (Target:DebuffP(S.ColossusSmashDebuff) and (S.DeadlyCalm:CooldownRemainsP() > 6 or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Ravager) then return ""; end
    end
    -- mortal_strike,if=buff.overpower.stack=2&(talent.dreadnaught.enabled|equipped.archavons_heavy_hand)
    if S.MortalStrike:IsCastableP() and (Player:BuffStackP(S.OverpowerBuff) == 2 and (S.Dreadnaught:IsAvailable() or I.ArchavonsHeavyHand:IsEquipped())) then
      if HR.Cast(S.MortalStrike) then return ""; end
    end
    -- overpower
    if S.Overpower:IsCastableP() then
      if HR.Cast(S.Overpower) then return ""; end
    end
    -- execute,if=rage>=40|debuff.colossus_smash.up|buff.sudden_death.react|buff.stone_heart.react
    if S.Execute:IsCastableP() and (Player:Rage() >= 40 or Target:DebuffP(S.ColossusSmashDebuff) or bool(Player:BuffStackP(S.SuddenDeathBuff)) or bool(Player:BuffStackP(S.StoneHeartBuff))) then
      if HR.Cast(S.Execute) then return ""; end
    end
  end
  FiveTarget = function()
    -- skullsplitter,if=rage<70&(cooldown.deadly_calm.remains>3|!talent.deadly_calm.enabled)
    if S.Skullsplitter:IsCastableP() and (Player:Rage() < 70 and (S.DeadlyCalm:CooldownRemainsP() > 3 or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Skullsplitter) then return ""; end
    end
    -- deadly_calm,if=cooldown.bladestorm.remains>6&((cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2))|(equipped.weight_of_the_earth&cooldown.heroic_leap.remains<2))
    if S.DeadlyCalm:IsCastableP() and (S.Bladestorm:CooldownRemainsP() > 6 and ((S.ColossusSmash:CooldownRemainsP() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 2)) or (I.WeightoftheEarth:IsEquipped() and S.HeroicLeap:CooldownRemainsP() < 2))) then
      if HR.Cast(S.DeadlyCalm) then return ""; end
    end
    -- colossus_smash,if=debuff.colossus_smash.down
    if S.ColossusSmash:IsCastableP() and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.ColossusSmash) then return ""; end
    end
    -- warbreaker,if=debuff.colossus_smash.down
    if S.Warbreaker:IsCastableP() and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Warbreaker) then return ""; end
    end
    -- heroic_leap,if=equipped.weight_of_the_earth&debuff.colossus_smash.down&((cooldown.colossus_smash.remains>8&!prev_gcd.1.colossus_smash)|(talent.warbreaker.enabled&cooldown.warbreaker.remains>8&!prev_gcd.1.warbreaker))
    if S.HeroicLeap:IsCastableP() and (I.WeightoftheEarth:IsEquipped() and Target:DebuffDownP(S.ColossusSmashDebuff) and ((S.ColossusSmash:CooldownRemainsP() > 8 and not Player:PrevGCDP(1, S.ColossusSmash)) or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() > 8 and not Player:PrevGCDP(1, S.Warbreaker)))) then
      if HR.Cast(S.HeroicLeap) then return ""; end
    end
    -- bladestorm,if=buff.sweeping_strikes.down&debuff.colossus_smash.remains>4.5&(prev_gcd.1.mortal_strike|spell_targets.whirlwind>1)&(!buff.deadly_calm.up|!talent.deadly_calm.enabled)
    if S.Bladestorm:IsCastableP() and (Player:BuffDownP(S.SweepingStrikesBuff) and Target:DebuffRemainsP(S.ColossusSmashDebuff) > 4.5 and (Player:PrevGCDP(1, S.MortalStrike) or Cache.EnemiesCount[8] > 1) and (not Player:BuffP(S.DeadlyCalmBuff) or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Bladestorm) then return ""; end
    end
    -- ravager,if=debuff.colossus_smash.up&(cooldown.deadly_calm.remains>6|!talent.deadly_calm.enabled)
    if S.Ravager:IsCastableP() and (Target:DebuffP(S.ColossusSmashDebuff) and (S.DeadlyCalm:CooldownRemainsP() > 6 or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Ravager) then return ""; end
    end
    -- execute,if=(!talent.cleave.enabled&dot.deep_wounds.remains<2)|(buff.sudden_death.react|buff.stone_heart.react)&(buff.sweeping_strikes.up|cooldown.sweeping_strikes.remains>8)
    if S.Execute:IsCastableP() and ((not S.Cleave:IsAvailable() and Target:DebuffRemainsP(S.DeepWoundsDebuff) < 2) or (bool(Player:BuffStackP(S.SuddenDeathBuff)) or bool(Player:BuffStackP(S.StoneHeartBuff))) and (Player:BuffP(S.SweepingStrikesBuff) or S.SweepingStrikes:CooldownRemainsP() > 8)) then
      if HR.Cast(S.Execute) then return ""; end
    end
    -- mortal_strike,if=(!talent.cleave.enabled&dot.deep_wounds.remains<2)|buff.sweeping_strikes.up&buff.overpower.stack=2&(talent.dreadnaught.enabled|equipped.archavons_heavy_hand)
    if S.MortalStrike:IsCastableP() and ((not S.Cleave:IsAvailable() and Target:DebuffRemainsP(S.DeepWoundsDebuff) < 2) or Player:BuffP(S.SweepingStrikesBuff) and Player:BuffStackP(S.OverpowerBuff) == 2 and (S.Dreadnaught:IsAvailable() or I.ArchavonsHeavyHand:IsEquipped())) then
      if HR.Cast(S.MortalStrike) then return ""; end
    end
    -- whirlwind,if=debuff.colossus_smash.up
    if S.Whirlwind:IsCastableP() and (Target:DebuffP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Whirlwind) then return ""; end
    end
    -- overpower
    if S.Overpower:IsCastableP() then
      if HR.Cast(S.Overpower) then return ""; end
    end
    -- whirlwind
    if S.Whirlwind:IsCastableP() then
      if HR.Cast(S.Whirlwind) then return ""; end
    end
  end
  SingleTarget = function()
    -- rend,if=remains<=duration*0.3&debuff.colossus_smash.down
    if S.Rend:IsCastableP() and (Target:DebuffRemainsP(S.RendDebuff) <= S.RendDebuff:BaseDuration() * 0.3 and Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Rend) then return ""; end
    end
    -- skullsplitter,if=rage<70&(cooldown.deadly_calm.remains>3|!talent.deadly_calm.enabled)
    if S.Skullsplitter:IsCastableP() and (Player:Rage() < 70 and (S.DeadlyCalm:CooldownRemainsP() > 3 or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Skullsplitter) then return ""; end
    end
    -- deadly_calm,if=cooldown.bladestorm.remains>6&((cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2))|(equipped.weight_of_the_earth&cooldown.heroic_leap.remains<2))
    if S.DeadlyCalm:IsCastableP() and (S.Bladestorm:CooldownRemainsP() > 6 and ((S.ColossusSmash:CooldownRemainsP() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 2)) or (I.WeightoftheEarth:IsEquipped() and S.HeroicLeap:CooldownRemainsP() < 2))) then
      if HR.Cast(S.DeadlyCalm) then return ""; end
    end
    -- colossus_smash,if=debuff.colossus_smash.down
    if S.ColossusSmash:IsCastableP() and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.ColossusSmash) then return ""; end
    end
    -- warbreaker,if=debuff.colossus_smash.down
    if S.Warbreaker:IsCastableP() and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Warbreaker) then return ""; end
    end
    -- heroic_leap,if=equipped.weight_of_the_earth&debuff.colossus_smash.down&((cooldown.colossus_smash.remains>8&!prev_gcd.1.colossus_smash)|(talent.warbreaker.enabled&cooldown.warbreaker.remains>8&!prev_gcd.1.warbreaker))
    if S.HeroicLeap:IsCastableP() and (I.WeightoftheEarth:IsEquipped() and Target:DebuffDownP(S.ColossusSmashDebuff) and ((S.ColossusSmash:CooldownRemainsP() > 8 and not Player:PrevGCDP(1, S.ColossusSmash)) or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() > 8 and not Player:PrevGCDP(1, S.Warbreaker)))) then
      if HR.Cast(S.HeroicLeap) then return ""; end
    end
    -- execute,if=buff.sudden_death.react|buff.stone_heart.react
    if S.Execute:IsCastableP() and (bool(Player:BuffStackP(S.SuddenDeathBuff)) or bool(Player:BuffStackP(S.StoneHeartBuff))) then
      if HR.Cast(S.Execute) then return ""; end
    end
    -- bladestorm,if=buff.sweeping_strikes.down&debuff.colossus_smash.remains>4.5&(prev_gcd.1.mortal_strike|spell_targets.whirlwind>1)&(!buff.deadly_calm.up|!talent.deadly_calm.enabled)
    if S.Bladestorm:IsCastableP() and (Player:BuffDownP(S.SweepingStrikesBuff) and Target:DebuffRemainsP(S.ColossusSmashDebuff) > 4.5 and (Player:PrevGCDP(1, S.MortalStrike) or Cache.EnemiesCount[8] > 1) and (not Player:BuffP(S.DeadlyCalmBuff) or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Bladestorm) then return ""; end
    end
    -- ravager,if=debuff.colossus_smash.up&(cooldown.deadly_calm.remains>6|!talent.deadly_calm.enabled)
    if S.Ravager:IsCastableP() and (Target:DebuffP(S.ColossusSmashDebuff) and (S.DeadlyCalm:CooldownRemainsP() > 6 or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Ravager) then return ""; end
    end
    -- mortal_strike
    if S.MortalStrike:IsCastableP() then
      if HR.Cast(S.MortalStrike) then return ""; end
    end
    -- overpower
    if S.Overpower:IsCastableP() then
      if HR.Cast(S.Overpower) then return ""; end
    end
    -- whirlwind,if=talent.fervor_of_battle.enabled&(rage>=50|debuff.colossus_smash.up)
    if S.Whirlwind:IsCastableP() and (S.FervorofBattle:IsAvailable() and (Player:Rage() >= 50 or Target:DebuffP(S.ColossusSmashDebuff))) then
      if HR.Cast(S.Whirlwind) then return ""; end
    end
    -- slam,if=!talent.fervor_of_battle.enabled&(rage>=40|debuff.colossus_smash.up)
    if S.Slam:IsCastableP() and (not S.FervorofBattle:IsAvailable() and (Player:Rage() >= 40 or Target:DebuffP(S.ColossusSmashDebuff))) then
      if HR.Cast(S.Slam) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  -- charge
  if S.Charge:IsCastableP() then
    if HR.Cast(S.Charge, Settings.Arms.GCDasOffGCD.Charge) then return ""; end
  end
  -- auto_attack
  -- potion
  if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.ProlongedPower) then return ""; end
  end
  -- blood_fury,if=debuff.colossus_smash.up
  if S.BloodFury:IsCastableP() and HR.CDsON() and (Target:DebuffP(S.ColossusSmashDebuff)) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- berserking,if=debuff.colossus_smash.up
  if S.Berserking:IsCastableP() and HR.CDsON() and (Target:DebuffP(S.ColossusSmashDebuff)) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- arcane_torrent,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains>1.5&rage<50
  if S.ArcaneTorrent:IsCastableP() and HR.CDsON() and (Target:DebuffDownP(S.ColossusSmashDebuff) and S.MortalStrike:CooldownRemainsP() > 1.5 and Player:Rage() < 50) then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- lights_judgment,if=debuff.colossus_smash.down
  if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
    if HR.Cast(S.LightsJudgment) then return ""; end
  end
  -- avatar,if=cooldown.colossus_smash.remains<8|(talent.warbreaker.enabled&cooldown.warbreaker.remains<8)
  if S.Avatar:IsCastableP() and HR.CDsON() and (S.ColossusSmash:CooldownRemainsP() < 8 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 8)) then
    if HR.Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return ""; end
  end
  -- sweeping_strikes,if=spell_targets.whirlwind>1
  if S.SweepingStrikes:IsCastableP() and (Cache.EnemiesCount[8] > 1) then
    if HR.Cast(S.SweepingStrikes) then return ""; end
  end
  -- run_action_list,name=five_target,if=spell_targets.whirlwind>4
  if (Cache.EnemiesCount[8] > 4) then
    return FiveTarget();
  end
  -- run_action_list,name=execute,if=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20
  if ((S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20) then
    return Execute();
  end
  -- run_action_list,name=single_target
  if (true) then
    return SingleTarget();
  end
end

HR.SetAPL(71, APL)
