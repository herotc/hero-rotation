--- Localize Vars
-- Addon
local addonName, addonTable = ...;
-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
-- HeroRotation
local HR = HeroRotation;
-- Lua


--- APL Local Vars
-- Commons
  local Everyone = HR.Commons.Everyone;
-- Spells
  if not Spell.Warrior then Spell.Warrior = {}; end
  Spell.Warrior.Fury = {
    -- Racials
    ArcaneTorrent                 = Spell(80483),
    AncestralCall                 = Spell(274738),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    Fireblood                     = Spell(265221),
    GiftoftheNaaru                = Spell(59547),
    LightsJudgment                = Spell(255647),
    -- Abilities
    BattleShout                   = Spell(6673),
    BerserkerRage                 = Spell(18499),
    Bloodthirst                   = Spell(23881),
    Charge                        = Spell(100),
    Execute                       = Spell(5308),
    HeroicLeap                    = Spell(6544),
    HeroicThrow                   = Spell(57755),
    RagingBlow                    = Spell(85288),
    Rampage                       = Spell(184367),
    Recklessness                  = Spell(1719),
    VictoryRush                   = Spell(34428),
    Whirlwind                     = Spell(190411),
    Enrage                        = Spell(184362),
    -- Talents
    WarMachine                    = Spell(262231),
    EndlessRage                   = Spell(202296),
    FreshMeat                     = Spell(215568),
    DoubleTime                    = Spell(103827),
    ImpendingVictory              = Spell(202168),
    StormBolt                     = Spell(107570),
    InnerRage                     = Spell(215573),
    FuriousSlash                  = Spell(100130),
    FuriousSlashBuff              = Spell(202539),
    Carnage                       = Spell(202922),
    Massacre                      = Spell(206315),
    FrothingBerserker             = Spell(215571),
    MeatCleaver                   = Spell(280392),
    DragonRoar                    = Spell(118000),
    Bladestorm                    = Spell(46924),
    RecklessAbandon               = Spell(202751),
    AngerManagement               = Spell(152278),
    Siegebreaker                  = Spell(280772),
    SiegebreakerDebuff            = Spell(280773),
    -- Defensive
    -- Utility
    Pummel                         = Spell(6552),
    -- Legendaries
    FujiedasFury                  = Spell(207776),
    StoneHeart                    = Spell(225947),
    -- Misc
    UmbralMoonglaives             = Spell(242553),
  };
  local S = Spell.Warrior.Fury;
-- Items
  if not Item.Warrior then Item.Warrior = {}; end
  Item.Warrior.Fury = {
    -- Legendaries
    KazzalaxFujiedasFury          = Item(137053, {15}),
    NajentussVertebrae            = Item(137087, {6}),
    -- Trinkets
    ConvergenceofFates            = Item(140806, {13, 14}),
    DraughtofSouls                = Item(140808, {13, 14}),
    UmbralMoonglaives             = Item(147012, {13, 14}),
    -- Potions
    PotionOfProlongedPower        = Item(142117),
    PotionoftheOldWar             = Item(127844),
  };
  local I = Item.Warrior.Fury;
-- Rotation Var
  local ShouldReturn; -- Used to get the return string
-- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Warrior.Commons,
    Fury    = HR.GUISettings.APL.Warrior.Fury
  };


--- APL Action Lists (and Variables)
  -- # single_target
  local function single_target ()
    -- actions.single_target=siegebreaker,if=buff.recklessness.up|cooldown.recklessness.remains>28
    if S.Siegebreaker:IsReady() and S.Siegebreaker:IsAvailable() and (Player:Buff(S.Recklessness) or S.Recklessness:CooldownRemainsP() > 28 ) then
      if HR.Cast(S.Siegebreaker) then return ""; end
    end
    -- actions.single_target+=/rampage,if=buff.recklessness.up|(talent.frothing_berserker.enabled|talent.carnage.enabled&(buff.enrage.remains<gcd|rage>90)|talent.massacre.enabled&(buff.enrage.remains<gcd|rage>90))
    if S.Rampage:IsReady() and (Player:Buff(S.Recklessness) or (S.FrothingBerserker:IsAvailable() or S.Carnage:IsAvailable() and (Player:BuffRemainsP(S.Enrage) < Player:GCD() or Player:Rage() > 90) or S.Massacre:IsAvailable() and (Player:BuffRemainsP(S.Enrage) < Player:GCD() or Player:Rage() > 90))) then
      if HR.Cast(S.Rampage) then return ""; end
    end
    -- actions.single_target+=/execute,if=buff.enrage.up
    if S.Execute:IsReady() and Player:Buff(S.Enrage) then
      if HR.Cast(S.Execute) then return ""; end
    end
    -- actions.single_target+=/bloodthirst,if=buff.enrage.down
    if S.Bloodthirst:IsCastable() and not Player:Buff(S.Enrage) then
      if HR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.single_target+=/raging_blow,if=charges=2
    if S.RagingBlow:IsReady() and S.RagingBlow:Charges() == 2 then
      if HR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.single_target+=/bloodthirst
    if S.Bloodthirst:IsCastable() then
      if HR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.single_target+=/bladestorm,if=prev_gcd.1.rampage&(debuff.siegebreaker.up|!talent.siegebreaker.enabled)
    if HR.CDsON() and S.Bladestorm:IsCastable() and Player:PrevGCDP(1, S.Rampage) and (Target:Debuff(S.SiegebreakerDebuff) or not S.Siegebreaker:IsAvailable()) then
      if HR.Cast(S.Bladestorm) then return ""; end
    end
    -- actions.single_target+=/dragon_roar,if=buff.enrage.up&(debuff.siegebreaker.up|!talent.siegebreaker.enabled)
    if HR.CDsON() and S.DragonRoar:IsCastable() and Player:Buff(S.Enrage) and (Target:Debuff(S.SiegebreakerDebuff) or not S.Siegebreaker:IsAvailable()) then
      if HR.Cast(S.DragonRoar, Settings.Fury.GCDasOffGCD.DragonRoar) then return ""; end
    end
    -- actions.single_target+=/raging_blow,if=talent.carnage.enabled|(talent.massacre.enabled&rage<80)|(talent.frothing_berserker.enabled&rage<90)
    if S.RagingBlow:IsReady() and S.Carnage:IsAvailable() or (S.Massacre:IsAvailable() and Player:Rage() < 80) or (S.FrothingBerserker:IsAvailable() and Player:Rage() < 90) then
      if HR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.single_target+=/furious_slash,if=talent.furious_slash.enabled
    if S.FuriousSlash:IsCastable() and S.FuriousSlash:IsAvailable() then
      if HR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.single_target+=/whirlwind
    if S.Whirlwind:IsCastable() then
      if HR.Cast(S.Whirlwind) then return ""; end
    end
    return false;
  end

-- APL Main
local function APL ()
-- Unit Update
  HL.GetEnemies(8);
  HL.GetEnemies(10);
  Everyone.AoEToggleEnemiesUpdate();

  --- In Combat
  if Everyone.TargetIsValid() then
  -- actions+=/charge
  if S.Charge:IsCastable() and Target:IsInRange(S.Charge) then
    if HR.Cast(S.Charge) then return ""; end
  end
  -- Interrupts
  if Settings.General.InterruptEnabled and Target:IsInterruptible() and Target:IsInRange("Melee") then
    if S.Pummel:IsReady() then
      if HR.Cast(S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel) then return "Cast Pummel"; end
    end
  end
  -- actions+=/run_action_list,name=movement,if=movement.distance>5
  -- actions+=/heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)|!raid_event.movement.exists
  -- actions+=/potion
  -- actions+=/furious_slash,if=talent.furious_slash.enabled&(buff.furious_slash.stack<3|buff.furious_slash.remains<3|(cooldown.recklessness.remains<3&buff.furious_slash.remains<9))
  if S.FuriousSlash:IsCastable() and S.FuriousSlash:IsAvailable() and (Player:BuffStack(S.FuriousSlashBuff) < 3 or Player:BuffRemainsP(S.FuriousSlashBuff) < 3 or (S.Recklessness:CooldownRemainsP() < 3 and Player:BuffRemainsP(S.FuriousSlashBuff) < 9)) then
    if HR.Cast(S.FuriousSlash) then return ""; end
  end
  -- actions+=/bloodthirst,if=equipped.kazzalax_fujiedas_fury&(buff.fujiedas_fury.down|remains<2)
  if S.Bloodthirst:IsCastable() and I.KazzalaxFujiedasFury:IsEquipped() and (not Player:BuffP(S.FujiedasFury) or Player:BuffRemainsP(S.FujiedasFury) < 2) then
    if HR.Cast(S.Bloodthirst) then return ""; end
  end
  -- actions+=/rampage,if=cooldown.recklessness.remains<3
  if S.Rampage:IsReady() and S.Recklessness:CooldownRemainsP() < 3 then
    if HR.Cast(S.Rampage) then return ""; end
  end
  -- actions+=/recklessness
  if HR.CDsON() and S.Recklessness:IsCastable() then
    if HR.Cast(S.Recklessness) then return ""; end
  end
  -- actions+=/whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up
  if HR.AoEON() and S.Whirlwind:IsCastable() and Cache.EnemiesCount[8] > 1 and not Player:Buff(S.MeatCleaver) then
    if HR.Cast(S.Whirlwind) then return ""; end
  end
  if HR.CDsON() then
    -- actions+=/arcane_torrent,if=rage<40&!buff.recklessness.up
    if S.ArcaneTorrent:IsCastable() and Player:Rage() < 40 and not Player:Buff(S.Recklessness) then
      if HR.Cast(S.ArcaneTorrent, Settings.Fury.GCDasOffGCD.Racials) then return ""; end
    end
    -- actions+=/berserking,if=buff.recklessness.up
    if S.Berserking:IsCastable() and Player:Buff(S.Recklessness) then
      if HR.Cast(S.Berserking, Settings.Fury.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- actions+=/blood_fury,if=buff.recklessness.up
    if S.BloodFury:IsCastable() and Player:Buff(S.Recklessness) then
      if HR.Cast(S.BloodFury, Settings.Fury.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- actions+=/ancestral_call,if=buff.recklessness.up
    if S.AncestralCall:IsCastable() and Player:Buff(S.Recklessness) then
      if HR.Cast(S.AncestralCall, Settings.Fury.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- actions+=/fireblood,if=buff.recklessness.up
    if S.Fireblood:IsCastable() and Player:Buff(S.Recklessness) then
      if HR.Cast(S.Fireblood, Settings.Fury.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- actions+=/lights_judgment,if=cooldown.recklessness.remains<3
    if S.LightsJudgment:IsCastable() and S.Recklessness:CooldownRemainsP() < 3 then
      if HR.Cast(S.LightsJudgment, Settings.Fury.OffGCDasOffGCD.Racials) then return ""; end
    end
  end
  -- # Action list
    -- actions+=/run_action_list,name=single_target
        ShouldReturn = single_target();
        if ShouldReturn then return ShouldReturn; end
    return;
  end
end
HR.SetAPL(72, APL);

--- Last Update: 11/26/2017

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/charge
-- # This is mostly to prevent cooldowns from being accidentally used during movement.
-- actions+=/run_action_list,name=movement,if=movement.distance>5
-- actions+=/heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)|!raid_event.movement.exists
-- actions+=/potion,name=old_war,if=buff.battle_cry.up&(buff.avatar.up|!talent.avatar.enabled)
-- actions+=/dragon_roar,if=(equipped.convergence_of_fates&cooldown.battle_cry.remains<2)|!equipped.convergence_of_fates&(!cooldown.battle_cry.remains<=10|cooldown.battle_cry.remains<2)|(talent.bloodbath.enabled&(cooldown.bloodbath.remains<1|buff.bloodbath.up))
-- actions+=/rampage,if=cooldown.battle_cry.remains<1&cooldown.bloodbath.remains<1&target.health.pct>20
-- actions+=/furious_slash,if=talent.frenzy.enabled&(buff.frenzy.stack<3|buff.frenzy.remains<3|(cooldown.battle_cry.remains<1&buff.frenzy.remains<9))
-- actions+=/bloodthirst,if=equipped.kazzalax_fujiedas_fury&buff.fujiedas_fury.down
-- actions+=/avatar,if=((buff.battle_cry.remains>5|cooldown.battle_cry.remains<12)&target.time_to_die>80)|((target.time_to_die<40)&(buff.battle_cry.remains>6|cooldown.battle_cry.remains<12|(target.time_to_die<20)))
-- actions+=/use_item,name=umbral_moonglaives,if=equipped.umbral_moonglaives&(cooldown.battle_cry.remains>gcd&cooldown.battle_cry.remains<2|cooldown.battle_cry.remains=0)
-- actions+=/battle_cry,if=gcd.remains=0&talent.reckless_abandon.enabled&!talent.bloodbath.enabled&(equipped.umbral_moonglaives&(prev_off_gcd.umbral_moonglaives|(trinket.cooldown.remains>3&trinket.cooldown.remains<90))|!equipped.umbral_moonglaives)
-- actions+=/battle_cry,if=gcd.remains=0&talent.bladestorm.enabled&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)
-- actions+=/battle_cry,if=gcd.remains=0&buff.dragon_roar.up&(cooldown.bloodthirst.remains=0|buff.enrage.remains>cooldown.bloodthirst.remains)
-- actions+=/battle_cry,if=(gcd.remains=0|gcd.remains<=0.4&prev_gcd.1.rampage)&(cooldown.bloodbath.remains=0|buff.bloodbath.up|!talent.bloodbath.enabled|(target.time_to_die<12))
-- actions+=/bloodbath,if=buff.battle_cry.up|(target.time_to_die<14)|(cooldown.battle_cry.remains<2&prev_gcd.1.rampage)
-- actions+=/blood_fury,if=buff.battle_cry.up
-- actions+=/berserking,if=(buff.battle_cry.up&(buff.avatar.up|!talent.avatar.enabled))|(buff.battle_cry.up&target.time_to_die<40)
-- actions+=/arcane_torrent,if=rage<rage.max-40
-- actions+=/run_action_list,name=cooldowns,if=buff.battle_cry.up&spell_targets.whirlwind=1
-- actions+=/run_action_list,name=three_targets,if=target.health.pct>20&(spell_targets.whirlwind=3|spell_targets.whirlwind=4)
-- actions+=/run_action_list,name=aoe,if=spell_targets.whirlwind>4
-- actions+=/run_action_list,name=execute,if=target.health.pct<20
-- actions+=/run_action_list,name=single_target,if=target.health.pct>20

-- actions.aoe=bloodthirst,if=buff.enrage.down|rage<90
-- actions.aoe+=/bladestorm,if=buff.enrage.remains>2&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)
-- actions.aoe+=/whirlwind,if=buff.meat_cleaver.down
-- actions.aoe+=/rampage,if=buff.meat_cleaver.up&(buff.enrage.down&!talent.frothing_berserker.enabled|buff.massacre.react|rage>=100)
-- actions.aoe+=/bloodthirst
-- actions.aoe+=/whirlwind

-- actions.cooldowns=rampage,if=buff.massacre.react&buff.enrage.remains<1
-- actions.cooldowns+=/bloodthirst,if=target.health.pct<20&buff.enrage.remains<1
-- actions.cooldowns+=/execute
-- actions.cooldowns+=/raging_blow,if=talent.inner_rage.enabled&buff.enrage.up
-- actions.cooldowns+=/rampage,if=(rage>=100&talent.frothing_berserker.enabled&!set_bonus.tier21_4pc)|set_bonus.tier21_4pc|!talent.frothing_berserker.enabled
-- actions.cooldowns+=/odyns_fury,if=buff.enrage.up&(cooldown.raging_blow.remains>0|!talent.inner_rage.enabled)
-- actions.cooldowns+=/berserker_rage,if=talent.outburst.enabled&buff.enrage.down&buff.battle_cry.up
-- actions.cooldowns+=/bloodthirst,if=(buff.enrage.remains<1&!talent.outburst.enabled)|!talent.inner_rage.enabled
-- actions.cooldowns+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
-- actions.cooldowns+=/raging_blow
-- actions.cooldowns+=/bloodthirst
-- actions.cooldowns+=/furious_slash

-- actions.execute=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
-- actions.execute+=/execute,if=artifact.juggernaut.enabled&(!buff.juggernaut.up|buff.juggernaut.remains<2)|buff.stone_heart.react
-- actions.execute+=/furious_slash,if=talent.frenzy.enabled&buff.frenzy.remains<=2
-- actions.execute+=/rampage,if=buff.massacre.react&buff.enrage.remains<1
-- actions.execute+=/execute
-- actions.execute+=/odyns_fury
-- actions.execute+=/bloodthirst
-- actions.execute+=/furious_slash,if=set_bonus.tier19_2pc
-- actions.execute+=/raging_blow
-- actions.execute+=/furious_slash

-- actions.movement=heroic_leap

-- actions.single_target=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
-- actions.single_target+=/furious_slash,if=talent.frenzy.enabled&(buff.frenzy.down|buff.frenzy.remains<=2)
-- actions.single_target+=/raging_blow,if=buff.enrage.up&talent.inner_rage.enabled
-- actions.single_target+=/rampage,if=target.health.pct>21&(rage>=100|!talent.frothing_berserker.enabled)&(((cooldown.battle_cry.remains>5|cooldown.bloodbath.remains>5)&!talent.carnage.enabled)|((cooldown.battle_cry.remains>3|cooldown.bloodbath.remains>3)&talent.carnage.enabled))|buff.massacre.react
-- actions.single_target+=/execute,if=buff.stone_heart.react&((talent.inner_rage.enabled&cooldown.raging_blow.remains>1)|buff.enrage.up)
-- actions.single_target+=/bloodthirst
-- actions.single_target+=/furious_slash,if=set_bonus.tier19_2pc&!talent.inner_rage.enabled
-- actions.single_target+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
-- actions.single_target+=/raging_blow
-- actions.single_target+=/furious_slash

-- actions.three_targets=execute,if=buff.stone_heart.react
-- actions.three_targets+=/rampage,if=buff.meat_cleaver.up&((buff.enrage.down&!talent.frothing_berserker.enabled)|(rage>=100&talent.frothing_berserker.enabled))|buff.massacre.react
-- actions.three_targets+=/raging_blow,if=talent.inner_rage.enabled
-- actions.three_targets+=/bloodthirst
-- actions.three_targets+=/whirlwind
