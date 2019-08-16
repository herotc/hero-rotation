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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Warrior then Spell.Warrior = {} end
Spell.Warrior.Arms = {
  Skullsplitter                         = Spell(260643),
  DeadlyCalm                            = Spell(262228),
  DeadlyCalmBuff                        = Spell(262228),
  Ravager                               = Spell(152277),
  ColossusSmash                         = Spell(167105),
  Warbreaker                            = Spell(262161),
  ColossusSmashDebuff                   = Spell(208086),
  Bladestorm                            = Spell(227847),
  Cleave                                = Spell(845),
  Slam                                  = Spell(1464),
  CrushingAssaultBuff                   = Spell(278826),
  MortalStrike                          = Spell(12294),
  OverpowerBuff                         = Spell(7384),
  Dreadnaught                           = Spell(262150),
  ExecutionersPrecisionBuff             = Spell(242188),
  Execute                               = MultiSpell(163201, 281000),
  Overpower                             = Spell(7384),
  SweepingStrikesBuff                   = Spell(260708),
  TestofMight                           = Spell(275529),
  TestofMightBuff                       = Spell(275540),
  DeepWoundsDebuff                      = Spell(262115),
  SuddenDeathBuff                       = Spell(52437),
  StoneHeartBuff                        = Spell(225947),
  SweepingStrikes                       = Spell(260708),
  Whirlwind                             = Spell(1680),
  FervorofBattle                        = Spell(202316),
  Rend                                  = Spell(772),
  RendDebuff                            = Spell(772),
  AngerManagement                       = Spell(152278),
  SeismicWave                           = Spell(277639),
  Charge                                = Spell(100),
  HeroicLeap                            = Spell(6544),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  Avatar                                = Spell(107574),
  Massacre                              = Spell(281001),
  Pummel                                = Spell(6552),
  IntimidatingShout                     = Spell(5246),
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565),
  BloodoftheEnemy                       = MultiSpell(297108, 298273, 298277),
  MemoryofLucidDreams                   = MultiSpell(298357, 299372, 299374),
  PurifyingBlast                        = MultiSpell(295337, 299345, 299347),
  RippleInSpace                         = MultiSpell(302731, 302982, 302983),
  ConcentratedFlame                     = MultiSpell(295373, 299349, 299353),
  TheUnboundForce                       = MultiSpell(298452, 299376, 299378),
  WorldveinResonance                    = MultiSpell(295186, 298628, 299334),
  FocusedAzeriteBeam                    = MultiSpell(295258, 299336, 299338),
  GuardianofAzeroth                     = MultiSpell(295840, 299355, 299358),
  ConcentratedFlameBurn                 = Spell(295368),
  RecklessForceBuff                     = Spell(302932)
};
local S = Spell.Warrior.Arms;

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Arms = {
  PotionofUnbridledFury            = Item(169299),
  AzsharasFontofPower              = Item(169314),
  AshvanesRazorCoral               = Item(169311)
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

-- Stuns
local StunInterrupts = {
  {S.IntimidatingShout, "Cast Intimidating Shout (Interrupt)", function () return true; end},
};

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

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Movement, Execute, FiveTarget, Hac, SingleTarget
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- use_item,name=azsharas_font_of_power
      if I.AzsharasFontofPower:IsEquipReady() and Settings.Commons.UseTrinkets then
        if HR.Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power"; end
      end
      -- memory_of_lucid_dreams
      if S.MemoryofLucidDreams:IsCastableP() then
        if HR.Cast(S.MemoryofLucidDreams) then return "memory_of_lucid_dreams"; end
      end
      -- guardian_of_azeroth
      if S.GuardianofAzeroth:IsCastableP() then
        if HR.Cast(S.GuardianofAzeroth) then return "guardian_of_azeroth"; end
      end
      -- potion
      if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_strength 4"; end
      end
    end
  end
  Movement = function()
    -- heroic_leap
    if S.HeroicLeap:IsCastableP() then
      if HR.Cast(S.HeroicLeap, Settings.Arms.GCDasOffGCD.HeroicLeap) then return "heroic_leap 16"; end
    end
  end
  Execute = function()
    -- skullsplitter,if=rage<60&buff.deadly_calm.down&buff.memory_of_lucid_dreams.down
    if S.Skullsplitter:IsCastableP("Melee") and (Player:Rage() < 60 and Player:BuffDownP(S.DeadlyCalmBuff) and Player:BuffDownP(S.MemoryofLucidDreams)) then
      if HR.Cast(S.Skullsplitter) then return "skullsplitter 6"; end
    end
    -- ravager,if=!buff.deadly_calm.up&(cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2))
    if S.Ravager:IsCastableP(40) and HR.CDsON() and (not Player:BuffP(S.DeadlyCalmBuff) and (S.ColossusSmash:CooldownRemainsP() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 2))) then
      if HR.Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager) then return "ravager 12"; end
    end
    -- colossus_smash,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>10)
    if S.ColossusSmash:IsCastableP("Melee") and (not S.MemoryofLucidDreams:IsAvailable() or (Player:BuffP(S.MemoryofLucidDreams) or S.MemoryofLucidDreams:CooldownRemainsP() > 10)) then
      if HR.Cast(S.ColossusSmash) then return "colossus_smash 22"; end
    end
    -- warbreaker,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>10)
    if S.Warbreaker:IsCastableP("Melee") and HR.CDsON() and (not S.MemoryofLucidDreams:IsAvailable() or (Player:BuffP(S.MemoryofLucidDreams) or S.MemoryofLucidDreams:CooldownRemainsP() > 10)) then
      if HR.Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker) then return "warbreaker 26"; end
    end
    -- deadly_calm
    if S.DeadlyCalm:IsCastableP() then
      if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm 30"; end
    end
    -- bladestorm,if=!buff.memory_of_lucid_dreams.up&buff.test_of_might.up&rage<30&!buff.deadly_calm.up
    if S.Bladestorm:IsCastableP() and HR.CDsON() and (Player:BuffDownP(S.MemoryofLucidDreams) and Player:BuffP(S.TestofMightBuff) and Player:Rage() < 30 and Player:BuffDownP(S.DeadlyCalmBuff)) then
      if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm) then return "bladestorm 32"; end
    end
    -- cleave,if=spell_targets.whirlwind>2
    if S.Cleave:IsReadyP("Melee") and (Cache.EnemiesCount[8] > 2) then
      if HR.Cast(S.Cleave) then return "cleave 36"; end
    end
    -- slam,if=buff.crushing_assault.up&buff.memory_of_lucid_dreams.down
    if S.Slam:IsReadyP("Melee") and (Player:BuffP(S.CrushingAssaultBuff) and Player:BuffDownP(S.MemoryofLucidDreams)) then
      if HR.Cast(S.Slam) then return "slam 38"; end
    end
    -- mortal_strike,if=buff.overpower.stack=2&talent.dreadnaught.enabled|buff.executioners_precision.stack=2
    if S.MortalStrike:IsReadyP("Melee") and (Player:BuffStackP(S.OverpowerBuff) == 2 and S.Dreadnaught:IsAvailable() or Player:BuffStackP(S.ExecutionersPrecisionBuff) == 2) then
      if HR.Cast(S.MortalStrike) then return "mortal_strike 42"; end
    end
    -- execute,if=buff.memory_of_lucid_dreams.up|buff.deadly_calm.up
    if S.Execute:IsReady("Melee") and (Player:BuffP(S.MemoryofLucidDreams) or Player:BuffP(S.DeadlyCalmBuff)) then
      if HR.Cast(S.Execute) then return "execute 50"; end
    end
    -- overpower
    if S.Overpower:IsCastableP("Melee") then
      if HR.Cast(S.Overpower) then return "overpower 54"; end
    end
    -- execute
    if S.Execute:IsReady("Melee") then
      if HR.Cast(S.Execute) then return "execute 56"; end
    end
  end
  FiveTarget = function()
    -- skullsplitter,if=rage<60&(!talent.deadly_calm.enabled|buff.deadly_calm.down)
    if S.Skullsplitter:IsCastableP("Melee") and (Player:Rage() < 60 and (not S.DeadlyCalm:IsAvailable() or Player:BuffDownP(S.DeadlyCalmBuff))) then
      if HR.Cast(S.Skullsplitter) then return "skullsplitter 58"; end
    end
    -- ravager,if=(!talent.warbreaker.enabled|cooldown.warbreaker.remains<2)
    if S.Ravager:IsCastableP(40) and HR.CDsON() and ((not S.Warbreaker:IsAvailable() or S.Warbreaker:CooldownRemainsP() < 2)) then
      if HR.Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager) then return "ravager 64"; end
    end
    -- colossus_smash,if=debuff.colossus_smash.down
    if S.ColossusSmash:IsCastableP("Melee") and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.ColossusSmash) then return "colossus_smash 70"; end
    end
    -- warbreaker,if=debuff.colossus_smash.down
    if S.Warbreaker:IsCastableP("Melee") and HR.CDsON() and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker) then return "warbreaker 74"; end
    end
    -- bladestorm,if=buff.sweeping_strikes.down&(!talent.deadly_calm.enabled|buff.deadly_calm.down)&((debuff.colossus_smash.remains>4.5&!azerite.test_of_might.enabled)|buff.test_of_might.up)
    if S.Bladestorm:IsCastableP() and HR.CDsON() and (Player:BuffDownP(S.SweepingStrikesBuff) and (not S.DeadlyCalm:IsAvailable() or Player:BuffDownP(S.DeadlyCalmBuff)) and ((Target:DebuffRemainsP(S.ColossusSmashDebuff) > 4.5 and not S.TestofMight:AzeriteEnabled()) or Player:BuffP(S.TestofMightBuff))) then
      if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm) then return "bladestorm 78"; end
    end
    -- deadly_calm
    if S.DeadlyCalm:IsCastableP() then
      if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm 92"; end
    end
    -- cleave
    if S.Cleave:IsReadyP("Melee") then
      if HR.Cast(S.Cleave) then return "cleave 94"; end
    end
    -- execute,if=(!talent.cleave.enabled&dot.deep_wounds.remains<2)|(buff.sudden_death.react|buff.stone_heart.react)&(buff.sweeping_strikes.up|cooldown.sweeping_strikes.remains>8)
    if S.Execute:IsReady("Melee") and ((not S.Cleave:IsAvailable() and Target:DebuffRemainsP(S.DeepWoundsDebuff) < 2) or (Player:BuffP(S.SuddenDeathBuff) or Player:BuffP(S.StoneHeartBuff)) and (Player:BuffP(S.SweepingStrikesBuff) or S.SweepingStrikes:CooldownRemainsP() > 8)) then
      if HR.Cast(S.Execute) then return "execute 96"; end
    end
    -- mortal_strike,if=(!talent.cleave.enabled&dot.deep_wounds.remains<2)|buff.sweeping_strikes.up&buff.overpower.stack=2&(talent.dreadnaught.enabled|buff.executioners_precision.stack=2)
    if S.MortalStrike:IsReadyP("Melee") and ((not S.Cleave:IsAvailable() and Target:DebuffRemainsP(S.DeepWoundsDebuff) < 2) or Player:BuffP(S.SweepingStrikesBuff) and Player:BuffStackP(S.OverpowerBuff) == 2 and (S.Dreadnaught:IsAvailable() or Player:BuffStackP(S.ExecutionersPrecisionBuff) == 2)) then
      if HR.Cast(S.MortalStrike) then return "mortal_strike 110"; end
    end
    -- whirlwind,if=debuff.colossus_smash.up|(buff.crushing_assault.up&talent.fervor_of_battle.enabled)
    if S.Whirlwind:IsReadyP("Melee") and (Target:DebuffP(S.ColossusSmashDebuff) or (Player:BuffP(S.CrushingAssaultBuff) and S.FervorofBattle:IsAvailable())) then
      if HR.Cast(S.Whirlwind) then return "whirlwind 124"; end
    end
    -- whirlwind,if=buff.deadly_calm.up|rage>60
    if S.Whirlwind:IsReadyP("Melee") and (Player:BuffP(S.DeadlyCalmBuff) or Player:Rage() > 60) then
      if HR.Cast(S.Whirlwind) then return "whirlwind 132"; end
    end
    -- overpower
    if S.Overpower:IsCastableP("Melee") then
      if HR.Cast(S.Overpower) then return "overpower 136"; end
    end
    -- whirlwind
    if S.Whirlwind:IsReadyP("Melee") then
      if HR.Cast(S.Whirlwind) then return "whirlwind 138"; end
    end
  end
  Hac = function()
    -- rend,if=remains<=duration*0.3&(!raid_event.adds.up|buff.sweeping_strikes.up)
    if S.Rend:IsReadyP("Melee") and (Target:DebuffRemainsP(S.RendDebuff) <= S.RendDebuff:BaseDuration() * 0.3 and (not (Cache.EnemiesCount[8] > 1) or Player:BuffP(S.SweepingStrikesBuff))) then
      if HR.Cast(S.Rend) then return "rend 140"; end
    end
    -- skullsplitter,if=rage<60&(cooldown.deadly_calm.remains>3|!talent.deadly_calm.enabled)
    if S.Skullsplitter:IsCastableP("Melee") and (Player:Rage() < 60 and (S.DeadlyCalm:CooldownRemainsP() > 3 or not S.DeadlyCalm:IsAvailable())) then
      if HR.Cast(S.Skullsplitter) then return "skullsplitter 158"; end
    end
    -- deadly_calm,if=(cooldown.bladestorm.remains>6|talent.ravager.enabled&cooldown.ravager.remains>6)&(cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2))
    if S.DeadlyCalm:IsCastableP() and ((S.Bladestorm:CooldownRemainsP() > 6 or S.Ravager:IsAvailable() and S.Ravager:CooldownRemainsP() > 6) and (S.ColossusSmash:CooldownRemainsP() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 2))) then
      if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm 164"; end
    end
    -- ravager,if=(raid_event.adds.up|raid_event.adds.in>target.time_to_die)&(cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2))
    if S.Ravager:IsCastableP(40) and HR.CDsON() and (((Cache.EnemiesCount[8] > 1) or 10000000000 > Target:TimeToDie()) and (S.ColossusSmash:CooldownRemainsP() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 2))) then
      if HR.Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager) then return "ravager 178"; end
    end
    -- colossus_smash,if=raid_event.adds.up|raid_event.adds.in>40|(raid_event.adds.in>20&talent.anger_management.enabled)
    if S.ColossusSmash:IsCastableP("Melee") and ((Cache.EnemiesCount[8] > 1) or 10000000000 > 40 or (10000000000 > 20 and S.AngerManagement:IsAvailable())) then
      if HR.Cast(S.ColossusSmash) then return "colossus_smash 188"; end
    end
    -- warbreaker,if=raid_event.adds.up|raid_event.adds.in>40|(raid_event.adds.in>20&talent.anger_management.enabled)
    if S.Warbreaker:IsCastableP("Melee") and HR.CDsON() and ((Cache.EnemiesCount[8] > 1) or 10000000000 > 40 or (10000000000 > 20 and S.AngerManagement:IsAvailable())) then
      if HR.Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker) then return "warbreaker 194"; end
    end
    -- bladestorm,if=(debuff.colossus_smash.up&raid_event.adds.in>target.time_to_die)|raid_event.adds.up&((debuff.colossus_smash.remains>4.5&!azerite.test_of_might.enabled)|buff.test_of_might.up)
    if S.Bladestorm:IsCastableP() and HR.CDsON() and ((Target:DebuffP(S.ColossusSmashDebuff) and 10000000000 > Target:TimeToDie()) or (Cache.EnemiesCount[8] > 1) and ((Target:DebuffRemainsP(S.ColossusSmashDebuff) > 4.5 and not S.TestofMight:AzeriteEnabled()) or Player:BuffP(S.TestofMightBuff))) then
      if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm) then return "bladestorm 200"; end
    end
    -- overpower,if=!raid_event.adds.up|(raid_event.adds.up&azerite.seismic_wave.enabled)
    if S.Overpower:IsCastableP("Melee") and (not (Cache.EnemiesCount[8] > 1) or ((Cache.EnemiesCount[8] > 1) and S.SeismicWave:AzeriteEnabled())) then
      if HR.Cast(S.Overpower) then return "overpower 212"; end
    end
    -- cleave,if=spell_targets.whirlwind>2
    if S.Cleave:IsReadyP("Melee") and (Cache.EnemiesCount[8] > 2) then
      if HR.Cast(S.Cleave) then return "cleave 220"; end
    end
    -- execute,if=!raid_event.adds.up|(!talent.cleave.enabled&dot.deep_wounds.remains<2)|buff.sudden_death.react
    if S.Execute:IsReady("Melee") and ((not S.Cleave:IsAvailable() and Target:DebuffRemainsP(S.DeepWoundsDebuff) < 2) or Player:BuffStackP(S.SuddenDeathBuff)) then
      if HR.Cast(S.Execute) then return "execute 222"; end
    end
    -- mortal_strike,if=!raid_event.adds.up|(!talent.cleave.enabled&dot.deep_wounds.remains<2)
    if S.MortalStrike:IsReadyP("Melee") and (not S.Cleave:IsAvailable() and Target:DebuffRemainsP(S.DeepWoundsDebuff) < 2) then
      if HR.Cast(S.MortalStrike) then return "mortal_strike 232"; end
    end
    -- whirlwind,if=raid_event.adds.up
    if S.Whirlwind:IsReadyP("Melee") then
      if HR.Cast(S.Whirlwind) then return "whirlwind 240"; end
    end
    -- overpower
    if S.Overpower:IsCastableP("Melee") then
      if HR.Cast(S.Overpower) then return "overpower 244"; end
    end
    -- whirlwind,if=talent.fervor_of_battle.enabled
    if S.Whirlwind:IsReadyP("Melee") and (S.FervorofBattle:IsAvailable()) then
      if HR.Cast(S.Whirlwind) then return "whirlwind 246"; end
    end
    -- slam,if=!talent.fervor_of_battle.enabled&!raid_event.adds.up
    if S.Slam:IsReadyP("Melee") and (not S.FervorofBattle:IsAvailable()) then
      if HR.Cast(S.Slam) then return "slam 250"; end
    end
  end
  SingleTarget = function()
    -- rend,if=remains<=duration*0.3&debuff.colossus_smash.down
    if S.Rend:IsReadyP("Melee") and (Target:DebuffRemainsP(S.RendDebuff) <= S.RendDebuff:BaseDuration() * 0.3 and Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Rend) then return "rend 256"; end
    end
    -- skullsplitter,if=rage<60&buff.deadly_calm.down&buff.memory_of_lucid_dreams.down
    if S.Skullsplitter:IsCastableP("Melee") and (Player:Rage() < 60 and Player:BuffDownP(S.DeadlyCalmBuff) and Player:BuffDownP(S.MemoryofLucidDreams)) then
      if HR.Cast(S.Skullsplitter) then return "skullsplitter 272"; end
    end
    -- ravager,if=!buff.deadly_calm.up&(cooldown.colossus_smash.remains<2|(talent.warbreaker.enabled&cooldown.warbreaker.remains<2))
    if S.Ravager:IsCastableP(40) and HR.CDsON() and (not Player:BuffP(S.DeadlyCalmBuff) and (S.ColossusSmash:CooldownRemainsP() < 2 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 2))) then
      if HR.Cast(S.Ravager, Settings.Arms.GCDasOffGCD.Ravager) then return "ravager 278"; end
    end
    -- colossus_smash,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>10)
    if S.ColossusSmash:IsCastableP("Melee") and (not S.MemoryofLucidDreams:IsAvailable() or (Player:BuffP(S.MemoryofLucidDreams) or S.MemoryofLucidDreams:CooldownRemainsP() > 10)) then
      if HR.Cast(S.ColossusSmash) then return "colossus_smash 288"; end
    end
    -- warbreaker,if=!essence.memory_of_lucid_dreams.major|(buff.memory_of_lucid_dreams.up|cooldown.memory_of_lucid_dreams.remains>10)
    if S.Warbreaker:IsCastableP("Melee") and HR.CDsON() and (not S.MemoryofLucidDreams:IsAvailable() or (Player:BuffP(S.MemoryofLucidDreams) or S.MemoryofLucidDreams:CooldownRemainsP() > 10)) then
      if HR.Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker) then return "warbreaker 292"; end
    end
    -- deadly_calm
    if S.DeadlyCalm:IsCastableP() then
      if HR.Cast(S.DeadlyCalm, Settings.Arms.OffGCDasOffGCD.DeadlyCalm) then return "deadly_calm 296"; end
    end
    -- execute,if=buff.sudden_death.react
    if S.Execute:IsReady("Melee") and (Player:BuffP(S.SuddenDeathBuff)) then
      if HR.Cast(S.Execute) then return "execute 298"; end
    end
    -- bladestorm,if=cooldown.mortal_strike.remains&(!talent.deadly_calm.enabled|buff.deadly_calm.down)&((debuff.colossus_smash.up&!azerite.test_of_might.enabled)|buff.test_of_might.up)&buff.memory_of_lucid_dreams.down
    if S.Bladestorm:IsCastableP() and HR.CDsON() and (bool(S.MortalStrike:CooldownRemainsP()) and (not S.DeadlyCalm:IsAvailable() or Player:BuffDownP(S.DeadlyCalmBuff)) and ((Target:DebuffP(S.ColossusSmashDebuff) and not S.TestofMight:AzeriteEnabled()) or Player:BuffP(S.TestofMightBuff)) and Player:BuffDownP(S.MemoryofLucidDreams)) then
      if HR.Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm) then return "bladestorm 302"; end
    end
    -- cleave,if=spell_targets.whirlwind>2
    if S.Cleave:IsReadyP("Melee") and (Cache.EnemiesCount[8] > 2) then
      if HR.Cast(S.Cleave) then return "cleave 316"; end
    end
    -- overpower,if=rage<30&buff.memory_of_lucid_dreams.up&debuff.colossus_smash.up
    if S.Overpower:IsCastableP("Melee") and (Player:Rage() < 30 and Player:BuffP(S.MemoryofLucidDreams) and Target:DebuffP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Overpower) then return "overpower 318"; end
    end
    -- mortal_strike
    if S.MortalStrike:IsReadyP("Melee") then
      if HR.Cast(S.MortalStrike) then return "mortal_strike 322"; end
    end
    -- whirlwind,if=talent.fervor_of_battle.enabled&(buff.memory_of_lucid_dreams.up|buff.deadly_calm.up)
    if S.Whirlwind:IsReadyP("Melee") and (S.FervorofBattle:IsAvailable() and (Player:BuffP(S.MemoryofLucidDreams) or Player:BuffP(S.DeadlyCalmBuff))) then
      if HR.Cast(S.Whirlwind) then return "whirlwind 324"; end
    end
    -- overpower
    if S.Overpower:IsCastableP("Melee") then
      if HR.Cast(S.Overpower) then return "overpower 330"; end
    end
    -- whirlwind,if=talent.fervor_of_battle.enabled
    if S.Whirlwind:IsReadyP("Melee") and (S.FervorofBattle:IsAvailable()) then
      if HR.Cast(S.Whirlwind) then return "whirlwind 332"; end
    end
    -- slam,if=!talent.fervor_of_battle.enabled
    if S.Slam:IsReadyP("Melee") and (not S.FervorofBattle:IsAvailable()) then
      if HR.Cast(S.Slam) then return "slam 340"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- charge
    if S.Charge:IsReadyP() and S.Charge:ChargesP() >= 1 then
      if HR.Cast(S.Charge, Settings.Arms.GCDasOffGCD.Charge) then return "charge 351"; end
    end
    -- Interrupts
    Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts);
    -- auto_attack
    if ((not Target:IsInRange("Melee")) and Target:IsInRange(40)) then
      return Movement();
    end
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "battle_potion_of_strength 354"; end
    end
    -- blood_fury,if=debuff.colossus_smash.up
    if S.BloodFury:IsCastableP() and HR.CDsON() and (Target:DebuffP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 356"; end
    end
    -- berserking,if=debuff.colossus_smash.up
    if S.Berserking:IsCastableP() and HR.CDsON() and (Target:DebuffP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 360"; end
    end
    -- arcane_torrent,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains>1.5&rage<50
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() and (Target:DebuffDownP(S.ColossusSmashDebuff) and S.MortalStrike:CooldownRemainsP() > 1.5 and Player:Rage() < 50) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 364"; end
    end
    -- lights_judgment,if=debuff.colossus_smash.down
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Target:DebuffDownP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 370"; end
    end
    -- fireblood,if=debuff.colossus_smash.up
    if S.Fireblood:IsCastableP() and HR.CDsON() and (Target:DebuffP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 374"; end
    end
    -- ancestral_call,if=debuff.colossus_smash.up
    if S.AncestralCall:IsCastableP() and HR.CDsON() and (Target:DebuffP(S.ColossusSmashDebuff)) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 378"; end
    end
    -- use_item,name=ashvanes_razor_coral,if=!debuff.razor_coral_debuff.up|(target.health.pct<30.1&debuff.conductive_ink_debuff.up)|(!debuff.conductive_ink_debuff.up&(buff.memory_of_lucid_dreams.up|(debuff.colossus_smash.up&!essence.memory_of_lucid_dreams.major))
    if I.AshvanesRazorCoral:IsEquipReady() and Settings.Commons.UseTrinkets and (Target:DebuffDownP(S.RazorCoralDebuff) or (Target:HealthPercentage() < 30.1 and Target:DebuffP(S.ConductiveInkDebuff)) or (Target:DebuffDownP(S.ConductiveInkDebuff) and (Player:BuffP(S.MemoryofLucidDreams) or (Target:DebuffP(S.ColossusSmash) and not S.MemoryofLucidDreams:IsAvailable())))) then
      if HR.Cast(I.AshvanesRazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "ashvanes_razor_coral 381"; end
    end
    -- avatar,if=cooldown.colossus_smash.remains<8|(talent.warbreaker.enabled&cooldown.warbreaker.remains<8)
    if S.Avatar:IsCastableP() and HR.CDsON() and (S.ColossusSmash:CooldownRemainsP() < 8 or (S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemainsP() < 8)) then
      if HR.Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar 382"; end
    end
    -- sweeping_strikes,if=spell_targets.whirlwind>1&(cooldown.bladestorm.remains>10|cooldown.colossus_smash.remains>8|azerite.test_of_might.enabled)
    if S.SweepingStrikes:IsCastableP() and (Cache.EnemiesCount[8] > 1 and (S.Bladestorm:CooldownRemainsP() > 10 or S.ColossusSmash:CooldownRemainsP() > 8 or S.TestofMight:AzeriteEnabled())) then
      if HR.Cast(S.SweepingStrikes) then return "sweeping_strikes 390"; end
    end
    -- blood_of_the_enemy,if=buff.test_of_might.up|(debuff.colossus_smash.up&!azerite.test_of_might.enabled)
    if S.BloodoftheEnemy:IsCastableP() and (Player:BuffP(S.TestofMightBuff) or (Target:DebuffP(S.ColossusSmashDebuff) and not S.TestofMight:IsAvailable())) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy"; end
    end
    -- purifying_blast,if=!debuff.colossus_smash.up&!buff.test_of_might.up
    if S.PurifyingBlast:IsCastableP() and (not Target:DebuffP(S.ColossusSmashDebuff) and not Player:BuffP(S.TestofMightBuff)) then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast"; end
    end
    -- ripple_in_space,if=!debuff.colossus_smash.up&!buff.test_of_might.up
    if S.RippleInSpace:IsCastableP() and (not Target:DebuffP(S.ColossusSmashDebuff) and not Player:BuffP(S.TestofMightBuff)) then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
    end
    -- worldvein_resonance,if=!debuff.colossus_smash.up&!buff.test_of_might.up
    if S.WorldveinResonance:IsCastableP() and (not Target:DebuffP(S.ColossusSmashDebuff) and not Player:BuffP(S.TestofMightBuff)) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
    end
    -- focused_azerite_beam,if=!debuff.colossus_smash.up&!buff.test_of_might.up
    if S.FocusedAzeriteBeam:IsCastableP() and (not Target:DebuffP(S.ColossusSmashDebuff) and not Player:BuffP(S.TestofMightBuff)) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
    end
    -- concentrated_flame,if=!debuff.colossus_smash.up&!buff.test_of_might.up&dot.concentrated_flame_burn.remains=0
    if S.ConcentratedFlame:IsCastableP() and (Target:DebuffDownP(S.ColossusSmashDebuff) and Player:BuffDownP(S.TestofMightBuff) and Target:DebuffDownP(S.ConcentratedFlameBurn)) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame"; end
    end
    -- the_unbound_force,if=buff.reckless_force.up
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff)) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force"; end
    end
    -- guardian_of_azeroth,if=cooldown.colossus_smash.remains<10
    if S.GuardianofAzeroth:IsCastableP() and (S.ColossusSmash:CooldownRemainsP() < 10) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
    end
    -- memory_of_lucid_dreams,if=!talent.warbreaker.enabled&cooldown.colossus_smash.remains<3|cooldown.warbreaker.remains<3
    if S.MemoryofLucidDreams:IsCastableP() and (not S.Warbreaker:IsAvailable() and S.ColossusSmash:CooldownRemainsP() < 3 or S.Warbreaker:CooldownRemainsP() < 3) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
    -- run_action_list,name=hac,if=raid_event.adds.exists
    if (Cache.EnemiesCount[8] > 1) then
      return Hac();
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
end

local function Init ()
  HL.RegisterNucleusAbility(152277, 8, 6)               -- Ravager
  HL.RegisterNucleusAbility(227847, 8, 6)               -- Bladestorm
  HL.RegisterNucleusAbility(845, 8, 6)                  -- Cleave
  HL.RegisterNucleusAbility(1680, 8, 6)                 -- Whirlwind
end

HR.SetAPL(71, APL, Init)
