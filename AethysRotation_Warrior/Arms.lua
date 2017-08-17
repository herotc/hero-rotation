--- Localize Vars
-- Addon
local addonName, addonTable = ...;

-- AethysCore
local AC = AethysCore;
local Cache = AethysCache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;

-- AethysRotation
local AR = AethysRotation;

-- APL from Warrior_Arms_T20M on 7/31/2017

-- APL Local Vars
-- Spells
if not Spell.Warrior then Spell.Warrior = {}; end
Spell.Warrior.Arms = {
  -- Racials
  Berserking                     = Spell(26297),
  BloodFury                      = Spell(20572),
  ArcaneTorrent                  = Spell(28730),

  -- Abilities
  BattleCry                      = Spell(1719),
  BattleCryBuff                  = Spell(1719),
  ColossusSmash                  = Spell(167105),
  ColossusSmashDebuff            = Spell(208086),
  Execute                        = Spell(163201),
  ExecutionersPrecisionDebuff    = Spell(242188),
  Cleave                         = Spell(845),
  CleaveBuff                     = Spell(231833),

  Charge                         = Spell(100),
  Bladestorm                     = Spell(227847),
  MortalStrike                   = Spell(12294),
  WhirlWind                      = Spell(1680),
  HeroicThrow                    = Spell(57755),
  Slam                           = Spell(1464),

  -- Talents
  Dauntless                      = Spell(202297),
  Avatar                         = Spell(107574),
  AvatarBuff                     = Spell(107574),
  FocusedRage                    = Spell(207982),
  FocusedRageBuff                = Spell(207982),
  Rend                           = Spell(772),
  RendDebuff                     = Spell(772),
  Overpower                      = Spell(7384),
  Ravager                        = Spell(152277),
  StormBolt                      = Spell(107570),
  DeadlyCalm                     = Spell(227266),
  FervorOfBattle                 = Spell(202316),
  SweepingStrikes                = Spell(202161),
  AngerManagement                = Spell(152278),
  InForTheKill                   = Spell(248621),
  InForTheKillBuff               = Spell(248622),

  -- Artifact
  Warbreaker                     = Spell(209577),

  -- Defensive
  CommandingShout                = Spell(97462),
  DefensiveStance                = Spell(197690),
  DiebytheSword                  = Spell(118038),
  Victorious                     = Spell(32216),
  VictoryRush                    = Spell(34428),

  -- Utility
  Pummel                         = Spell(6552),
  Shockwave                      = Spell(46968),
  ShatteredDefensesBuff          = Spell(248625),
  PreciseStrikesBuff             = Spell(209492),

  -- Legendaries
  StoneHeartBuff                 = Spell(225947),

  -- Misc
  PoolFocus                      = Spell(9999000010)
}
local S = Spell.Warrior.Arms;

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Arms = {
  -- Legendaries
  TheGreatStormsEye = Item(151823, {1}),
};
local I = Item.Warrior.Arms;

-- GUI Settings
local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Warrior.Commons,
    Arms    = AR.GUISettings.APL.Warrior.Arms
}

-- APL Variables
local function battle_cry_deadly_calm()
  if Player:Buff(S.BattleCryBuff) and S.DeadlyCalm:IsAvailable() then return true
  else return false end
end

-- APL Main
local function APL ()
  -- Unit Update
  AC.GetEnemies(8);  -- WhirlWind
  AC.GetEnemies(5);  -- Melee

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Opener
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
      if S.Charge:IsReady() and (not Target:IsInRange(8) and Target:IsInRange(25)) then
        if AR.Cast(S.Charge) then return "Cast Charge" end
      end
    end
    return
  end

  -- Interrupts
  if Settings.General.InterruptEnabled and Target:IsInterruptible() and Target:IsInRange(5) then
    if S.Pummel:IsReady() then
      if AR.Cast(S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel) then return "Cast Pummel"; end
    end
  end

  -- In Combat
  if Target:Exists() and Player:CanAttack(Target) and Target:IsInRange(5) and not Target:IsDeadOrGhost() then
    -- Racial
    -- actions+=/blood_fury,if=buff.battle_cry.up|target.time_to_die<=16
    if S.BloodFury:IsReady() and AR.CDsON() and (Player:Buff(S.BattleCryBuff) or Target:TimeToDie() <= 16) then
      if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast BloodFury" end
    end

    -- Racial
    -- actions+=/berserking,if=buff.battle_cry.up|target.time_to_die<=11
    if S.Berserking:IsReady() and AR.CDsON() and (Player:Buff(S.BattleCryBuff) or Target:TimeToDie() <= 11) then
      if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
    end

    -- Racial
    -- actions+=/arcane_torrent,if=buff.battle_cry_deadly_calm.down&rage.deficit>40&cooldown.battle_cry.remains
    if S.ArcaneTorrent:IsReady() and AR.CDsON() and (not battle_cry_deadly_calm() and Player:RageDeficit() > 40 and S.BattleCry:CooldownRemains() > 0) then
      if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast ArcaneTorrent" end
    end

    -- Omit gcd.remains on this offGCD because we can't react quickly enough otherwise (the intention is to cast this before the next GCD ability, but is a OffGCD abiltiy).
    -- actions+=/avatar,if=gcd.remains<0.25&(buff.battle_cry.up|cooldown.battle_cry.remains<15)|target.time_to_die<=20
    if S.Avatar:IsReady() and AR.CDsON() and ((Player:Buff(S.BattleCryBuff) or S.BattleCry:Cooldown() < 15) or Target:TimeToDie() <= 20) then
      if AR.Cast(S.Avatar, Settings.Arms.OffGCDasOffGCD.Avatar) then return "Cast Avatar" end
    end

    -- Omit gcd.remains on this offGCD because we can't react quickly enough otherwise (the intention is to cast this before the next GCD ability, but is a OffGCD abiltiy).
    -- actions+=/battle_cry,if=target.time_to_die<=6|(gcd.remains<=0.5&prev_gcd.1.ravager)|!talent.ravager.enabled&!gcd.remains&target.debuff.colossus_smash.remains>=5&(!cooldown.bladestorm.remains|!set_bonus.tier20_4pc)&(!talent.rend.enabled|dot.rend.remains>4)
    if S.BattleCry:IsReady() and AR.CDsON() and (Target:TimeToDie() <= 6 or (Player:PrevGCD(1, S.Ravager)) or not S.Ravager:IsAvailable() and Target:DebuffRemains(S.ColossusSmashDebuff) >= 5 and (S.Bladestorm:CooldownRemains() == 0 or not AC.Tier20_4Pc) and (not S.Rend:IsAvailable() or Target:DebuffRemains(S.RendDebuff) > 4)) then
      if AR.Cast(S.BattleCry, Settings.Arms.OffGCDasOffGCD.BattleCry) then return "Cast BattleCry" end
    end

    -- actions+=/run_action_list,name=cleave,if=spell_targets.whirlwind>=2&talent.sweeping_strikes.enabled
    if Cache.EnemiesCount[8] >= 2 and S.SweepingStrikes:IsAvailable() then
      -- actions.cleave=mortal_strike
      if S.MortalStrike:IsReady() then
        if AR.Cast(S.MortalStrike) then return "Cast MortalStrike" end
      end

      -- actions.cleave+=/execute,if=buff.stone_heart.react
      if S.Execute:IsReady() and (Player:Buff(S.StoneHeartBuff)) then
        if AR.Cast(S.Execute) then return "Cast Execute" end
      end

      -- actions.cleave+=/colossus_smash,if=buff.shattered_defenses.down&buff.precise_strikes.down
      if S.ColossusSmash:IsReady() and (not Player:Buff(S.ShatteredDefensesBuff) and not Player:Buff(S.PreciseStrikesBuff)) then
        if AR.Cast(S.ColossusSmash) then return "Cast ColossusSmash" end
      end

      -- actions.cleave+=/warbreaker,if=buff.shattered_defenses.down
      if S.Warbreaker:IsReady() and (not Player:Buff(S.ShatteredDefensesBuff)) then
        if Settings.Arms.WarbreakerEnabled then
          if AR.Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker) then return "Cast Warbreaker" end
        end
      end

      -- actions.cleave+=/focused_rage,if=rage>100|buff.battle_cry_deadly_calm.up
      if S.FocusedRage:IsReady() and (Player:Rage() > 100 or battle_cry_deadly_calm()) then
        if AR.Cast(S.FocusedRage, Settings.Arms.OffGCDasOffGCD.FocusedRage) then return "Cast FocusedRage" end
      end

      -- actions.cleave+=/whirlwind,if=talent.fervor_of_battle.enabled&(debuff.colossus_smash.up|rage.deficit<50)&(!talent.focused_rage.enabled|buff.battle_cry_deadly_calm.up|buff.cleave.up)
      if S.WhirlWind:IsReady() and (S.FervorOfBattle:IsAvailable() and (Target:Debuff(S.ColossusSmashDebuff) or Player:RageDeficit() < 50) and (not S.FocusedRage:IsAvailable() or battle_cry_deadly_calm() or Player:Buff(S.CleaveBuff))) then
        if AR.Cast(S.WhirlWind) then return "Cast WhirlWind" end
      end

      -- actions.cleave+=/rend,if=remains<=duration*0.3
      if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Target:DebuffDuration(S.RendDebuff) * 0.3) then
        if AR.Cast(S.Rend) then return "Cast Rend" end
      end

      -- actions.cleave+=/bladestorm
      if S.Bladestorm:IsReady() then
        if AR.Cast(S.Bladestorm) then return "Cast Bladestorm" end
      end

      -- actions.cleave+=/cleave
      if S.Cleave:IsReady() then
        if AR.Cast(S.Cleave) then return "Cast Cleave" end
      end

      -- actions.cleave+=/whirlwind,if=rage>40|buff.cleave.up
      if S.WhirlWind:IsReady() and (Player:Rage() > 40 or Player:Buff(S.CleaveBuff)) then
        if AR.Cast(S.WhirlWind) then return "Cast WhirlWind" end
      end

      -- actions.cleave+=/shockwave
      if S.Shockwave:IsReady() then
        if AR.Cast(S.Shockwave) then return "Cast Shockwave" end
      end

      -- actions.cleave+=/storm_bolt
      if S.StormBolt:IsReady() then
        if AR.Cast(S.StormBolt) then return "Cast StormBolt" end
      end
    end

    -- actions+=/run_action_list,name=aoe,if=spell_targets.whirlwind>=5&!talent.sweeping_strikes.enabled
    if AR.AoEON() and (Cache.EnemiesCount[8] >= 5 and not S.SweepingStrikes:IsAvailable()) then
      -- actions.aoe=warbreaker,if=(cooldown.bladestorm.up|cooldown.bladestorm.remains<=gcd)&(cooldown.battle_cry.up|cooldown.battle_cry.remains<=gcd)
      if S.Warbreaker:IsReady() and ((S.Bladestorm:CooldownRemains() == 0 or S.Bladestorm:CooldownRemains() <= Player:GCD()) and (S.BattleCry:CooldownRemains() == 0 or S.BattleCry:CooldownRemains() <= Player:GCD())) then
        if Settings.Arms.WarbreakerEnabled then
          if AR.Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker) then return "Cast Warbreaker" end
        end
      end

      -- actions.aoe+=/bladestorm,if=buff.battle_cry.up&(set_bonus.tier20_4pc|equipped.the_great_storms_eye)
      if S.Bladestorm:IsReady() and (Player:Buff(S.BattleCryBuff) and (AC.Tier20_4Pc or I.TheGreatStormsEye:IsEquipped())) then
        if AR.Cast(S.Bladestorm) then return "Cast Bladestorm" end
      end

      -- actions.aoe+=/colossus_smash,if=buff.in_for_the_kill.down&talent.in_for_the_kill.enabled
      if S.ColossusSmash:IsReady() and (not Player:Buff(S.InForTheKillBuff) and S.InForTheKill:IsAvailable()) then
        if AR.Cast(S.ColossusSmash) then return "Cast ColossusSmash" end
      end

      -- actions.aoe+=/colossus_smash,cycle_targets=1,if=debuff.colossus_smash.down&spell_targets.whirlwind<=10
      if S.ColossusSmash:IsReady() and (not Target:Debuff(S.ColossusSmashDebuff) and Cache.EnemiesCount[8] <= 10) then
        if AR.Cast(S.ColossusSmash) then return "Cast ColossusSmash" end
      end

      -- actions.aoe+=/cleave,if=spell_targets.whirlwind>=5
      if S.Cleave:IsReady() and (Cache.EnemiesCount[8] >= 5) then
        if AR.Cast(S.Cleave) then return "Cast Cleave" end
      end

      -- actions.aoe+=/whirlwind,if=spell_targets.whirlwind>=5&buff.cleave.up
      if S.WhirlWind:IsReady() and (Cache.EnemiesCount[8] >= 5 and Player:Buff(S.CleaveBuff)) then
        if AR.Cast(S.WhirlWind) then return "Cast WhirlWind" end
      end

      -- actions.aoe+=/whirlwind,if=spell_targets.whirlwind>=7
      if S.WhirlWind:IsReady() and (Cache.EnemiesCount[8] >= 7) then
        if AR.Cast(S.WhirlWind) then return "Cast WhirlWind" end
      end

      -- actions.aoe+=/colossus_smash,if=buff.shattered_defenses.down
      if S.ColossusSmash:IsReady() and (not Player:Buff(S.ShatteredDefensesBuff)) then
        if AR.Cast(S.ColossusSmash) then return "Cast ColossusSmash" end
      end

      -- actions.aoe+=/execute,if=buff.stone_heart.react
      if S.Execute:IsReady() and (Player:Buff(S.StoneHeartBuff)) then
        if AR.Cast(S.Execute) then return "Cast Execute" end
      end

      -- actions.aoe+=/mortal_strike,if=buff.shattered_defenses.up|buff.executioners_precision.down
      if S.MortalStrike:IsReady() and (Player:Buff(S.ShatteredDefensesBuff) or not Target:Debuff(S.ExecutionersPrecisionDebuff)) then
        if AR.Cast(S.MortalStrike) then return "Cast MortalStrike" end
      end

      -- actions.aoe+=/rend,cycle_targets=1,if=remains<=duration*0.3&spell_targets.whirlwind<=3
      if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Target:DebuffDuration(S.RendDebuff) * 0.3 and Cache.EnemiesCount[8] <= 3) then
        if AR.Cast(S.Rend) then return "Cast Rend" end
      end

      -- actions.aoe+=/cleave
      if S.Cleave:IsReady() then
        if AR.Cast(S.Cleave) then return "Cast Cleave" end
      end

      -- actions.aoe+=/whirlwind
      if S.WhirlWind:IsReady() then
        if AR.Cast(S.WhirlWind) then return "Cast WhirlWind" end
      end
    end

    -- actions+=/run_action_list,name=execute,target_if=target.health.pct<=20&spell_targets.whirlwind<5
    if Target:HealthPercentage() <= 20 and Cache.EnemiesCount[8] < 5 then
      -- actions.execute=bladestorm,if=buff.battle_cry.up&(set_bonus.tier20_4pc|equipped.the_great_storms_eye)
      if S.Bladestorm:IsReady() and (Player:Buff(S.BattleCryBuff) and (AC.Tier20_4Pc or I.TheGreatStormsEye:IsEquipped())) then
        if AR.Cast(S.Bladestorm) then return "Cast Bladestorm" end
      end

      -- actions.execute+=/colossus_smash,if=buff.shattered_defenses.down&(buff.battle_cry.down|buff.battle_cry.remains>gcd.max)
      if S.ColossusSmash:IsReady() and (not Player:Buff(S.ShatteredDefensesBuff) and (not Player:Buff(S.BattleCryBuff) or Player:BuffRemains(S.BattleCryBuff) > Player:GCD())) then
        if AR.Cast(S.ColossusSmash) then return "Cast ColossusSmash" end
      end

      -- actions.execute+=/warbreaker,if=(raid_event.adds.in>90|!raid_event.adds.exists)&cooldown.mortal_strike.remains<=gcd.remains&buff.shattered_defenses.down&buff.executioners_precision.stack=2
      if S.Warbreaker:IsReady() and (S.MortalStrike:Cooldown() <= Player:GCDRemains() and not Player:Buff(S.ShatteredDefensesBuff) and Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2) then
        if Settings.Arms.WarbreakerEnabled then
          if AR.Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker) then return "Cast Warbreaker" end
        end
      end

      -- actions.execute+=/focused_rage,if=rage.deficit<35
      if S.FocusedRage:IsReady() and (Player:RageDeficit() < 35) then
        if AR.Cast(S.FocusedRage, Settings.Arms.OffGCDasOffGCD.FocusedRage) then return "Cast FocusedRage" end
      end

      -- actions.execute+=/rend,if=remains<5&cooldown.battle_cry.remains<2&(cooldown.bladestorm.remains<2|!set_bonus.tier20_4pc)
      if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) < 5 and S.BattleCry:CooldownRemains() < 2 and (S.Bladestorm:CooldownRemains() < 2 or not AC.Tier20_4Pc)) then
        if AR.Cast(S.Rend) then return "Cast Rend" end
      end

      -- actions.execute+=/ravager,if=cooldown.battle_cry.remains<=gcd&debuff.colossus_smash.remains>6
      if S.Ravager:IsReady() and (S.BattleCry:Cooldown() <= Player:GCD() and Target:DebuffRemains(S.ColossusSmashDebuff) > 6) then
        if AR.Cast(S.Ravager) then return "Cast Ravager" end
      end

      -- actions.execute+=/mortal_strike,if=buff.executioners_precision.stack=2&buff.shattered_defenses.up
      if S.MortalStrike:IsReady() and (Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2 and Player:Buff(S.ShatteredDefensesBuff)) then
        if AR.Cast(S.MortalStrike) then return "Cast MortalStrike" end
      end

      -- actions.execute+=/overpower,if=rage<40
      if S.Overpower:IsReady() and (Player:Rage() < 40)then
        if AR.Cast(S.Overpower) then return "Cast Overpower" end
      end

      -- actions.execute+=/execute,if=buff.shattered_defenses.down|rage>=40|talent.dauntless.enabled&rage>=36
      if S.Execute:IsReady() and (not Player:Buff(S.ShatteredDefensesBuff) or Player:Rage() >= 40 or S.Dauntless:IsAvailable() and Player:Rage() >= 36) then
        if AR.Cast(S.Execute) then return "Cast Execute" end
      end

      -- actions.execute+=/bladestorm,interrupt=1,if=(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)&!set_bonus.tier20_4pc
      if S.Bladestorm:IsReady() and (Cache.EnemiesCount[8] > 1 and not AC.Tier20_4Pc) then
        if AR.Cast(S.Bladestorm) then return "Cast Bladestorm" end
      end
    end

    -- actions+=/run_action_list,name=single,if=target.health.pct>20
    if Target:HealthPercentage() > 20 then
      -- actions.single=bladestorm,if=buff.battle_cry.up&set_bonus.tier20_4pc
      if S.Bladestorm:IsReady() and (Player:Buff(S.BattleCryBuff) and AC.Tier20_4Pc) then
        if AR.Cast(S.Bladestorm) then return "Cast Bladestorm" end
      end

      -- actions.single+=/colossus_smash,if=buff.shattered_defenses.down
      if S.ColossusSmash:IsReady() and (not Player:Buff(S.ShatteredDefensesBuff)) then
        if AR.Cast(S.ColossusSmash) then return "Cast ColossusSmash" end
      end

      -- actions.single+=/warbreaker,if=(raid_event.adds.in>90|!raid_event.adds.exists)&((talent.fervor_of_battle.enabled&debuff.colossus_smash.remains<gcd)|!talent.fervor_of_battle.enabled&((buff.stone_heart.up|cooldown.mortal_strike.remains<=gcd.remains)&buff.shattered_defenses.down))
      if S.Warbreaker:IsReady() and ((S.FervorOfBattle:IsAvailable() and Target:DebuffRemains(S.ColossusSmashDebuff) < Player:GCD()) or not S.FervorOfBattle:IsAvailable() and ((Player:Buff(S.StoneHeartBuff) or S.MortalStrike:CooldownRemains() <= Player:GCDRemains()) and not Player:Buff(S.ShatteredDefensesBuff))) then
        if Settings.Arms.WarbreakerEnabled then
          if AR.Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker) then return "Cast Warbreaker" end
        end
      end

      -- actions.single+=/focused_rage,if=!buff.battle_cry_deadly_calm.up&buff.focused_rage.stack<3&!cooldown.colossus_smash.up&(rage>=130|debuff.colossus_smash.down|talent.anger_management.enabled&cooldown.battle_cry.remains<=8)
      if S.FocusedRage:IsReady() and (not battle_cry_deadly_calm() and Player:BuffStack(S.FocusedRageBuff) < 3 and S.ColossusSmash:CooldownRemains() > 0 and (Player:Rage() >= 130 or Target:Debuff(S.ColossusSmashDebuff) or (S.AngerManagement:IsAvailable() and S.BattleCry:CooldownRemains() <= 8))) then
        if AR.Cast(S.FocusedRage, Settings.Arms.OffGCDasOffGCD.FocusedRage) then return "Cast FocusedRage" end
      end

      -- actions.single+=/rend,if=remains<=gcd.max|remains<5&cooldown.battle_cry.remains<2&(cooldown.bladestorm.remains<2|!set_bonus.tier20_4pc)
      if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) < 5 and S.BattleCry:CooldownRemains() < 2 and (S.Bladestorm:CooldownRemains() < 2 or not AC.Tier20_4Pc)) then
        if AR.Cast(S.Rend) then return "Cast Rend" end
      end

      -- actions.single+=/ravager,if=cooldown.battle_cry.remains<=gcd&debuff.colossus_smash.remains>6
      if S.Ravager:IsReady() and (S.BattleCry:Cooldown() <= Player:GCD() and Target:DebuffRemains(S.ColossusSmashDebuff) > 6) then
        if AR.Cast(S.Ravager) then return "Cast Ravager" end
      end

      -- actions.single+=/execute,if=buff.stone_heart.react
      if S.Execute:IsReady() and (Player:Buff(S.StoneHeartBuff)) then
        if AR.Cast(S.Execute) then return "Cast Execute" end
      end

      -- actions.single+=/overpower,if=buff.battle_cry.down
      if S.Overpower:IsReady() and (not Player:Buff(S.BattleCryBuff)) then
        if AR.Cast(S.Overpower) then return "Cast Overpower" end
      end

      -- actions.single+=/mortal_strike,if=buff.shattered_defenses.up|buff.executioners_precision.down
      if S.MortalStrike:IsReady() and (Player:Buff(S.ShatteredDefensesBuff) or not Target:Debuff(S.ExecutionersPrecisionDebuff)) then
        if AR.Cast(S.MortalStrike) then return "Cast MortalStrike" end
      end

      -- actions.single+=/rend,if=remains<=duration*0.3
      if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Target:DebuffDuration(S.RendDebuff) * 0.3) then
        if AR.Cast(S.Rend) then return "Cast Rend" end
      end

      -- actions.single+=/whirlwind,if=spell_targets.whirlwind>1|talent.fervor_of_battle.enabled
      if S.WhirlWind:IsReady() and (Cache.EnemiesCount[8] > 1 or S.FervorOfBattle:IsAvailable()) then
        if AR.Cast(S.WhirlWind) then return "Cast WhirlWind" end
      end

      -- actions.single+=/slam,if=spell_targets.whirlwind=1&!talent.fervor_of_battle.enabled&(rage>=52|!talent.rend.enabled|!talent.ravager.enabled)
      if S.Slam:IsReady() and (Cache.EnemiesCount[5] <= 1 and not S.FervorOfBattle:IsAvailable() and (Player:Rage() >= 52 or not S.Rend:IsAvailable() or not S.Ravager:IsAvailable())) then
        if AR.Cast(S.Slam) then return "Cast Slam" end
      end

      -- actions.single+=/overpower
      if S.Overpower:IsReady() then
        if AR.Cast(S.Overpower) then return "Cast Overpower" end
      end

      -- actions.single+=/bladestorm,if=(raid_event.adds.in>90|!raid_event.adds.exists)&!set_bonus.tier20_4pc
      if S.Bladestorm:IsReady() and (not AC.Tier20_4Pc) then
        if AR.Cast(S.Bladestorm) then return "Cast Bladestorm" end
      end
    end
    if AR.Cast(S.PoolFocus) then return "Cast PoolFocus" end
  end
end

AR.SetAPL(71, APL);
