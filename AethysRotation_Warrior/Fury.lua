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
-- Lua


--- APL Local Vars
-- Commons
  local Everyone = AR.Commons.Everyone;
-- Spells
  if not Spell.Warrior then Spell.Warrior = {}; end
  Spell.Warrior.Fury = {
    -- Racials
    ArcaneTorrent                 = Spell(69179),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    Shadowmeld                    = Spell(58984),
    -- Abilities
    BattleCry                     = Spell(1719),
    BerserkerRage                 = Spell(18499),
    Bloodthirst                   = Spell(23881),
    Charge                        = Spell(100),
    Enrage                        = Spell(184362),
    Execute                       = Spell(5308),
    FuriousSlash                  = Spell(100130),
    HeroicLeap                    = Spell(6544),
    HeroicThrow                   = Spell(57755),
    MeatCleaver                   = Spell(85739),
    RagingBlow                    = Spell(85288),
    Rampage                       = Spell(184367),
    Whirlwind                     = Spell(190411),
    -- Talents
    Avatar                        = Spell(107574),
    Bladestorm                    = Spell(46924),
    Bloodbath                     = Spell(12292),
    BoundingStride                = Spell(202163),
    Carnage                       = Spell(202922),
    DragonRoar                    = Spell(118000),
    Frenzy                        = Spell(206313),
    FrenzyBuff                    = Spell(202539),
    FrothingBerserker             = Spell(215571),
    InnerRage                     = Spell(215573),
    Massacre                      = Spell(206315),
    Outburst                      = Spell(206320),
    RecklessAbandon               = Spell(202751),
    WreckingBall                  = Spell(215569),
    -- Artifact
    Juggernaut                    = Spell(980),
    OdynsFury                     = Spell(205545),
    -- Defensive
    -- Utility
    -- Legendaries
    FujiedasFury                  = Spell(207775),
    StoneHeart                    = Spell(225947),
    -- Misc
  };
  local S = Spell.Warrior.Fury;
-- Items
  if not Item.Warrior then Item.Warrior = {}; end
  Item.Warrior.Fury = {
    DraughtofSouls                = Item(140808, {13, 14}),
    ConvergenceofFates            = Item(140806, {13, 14}),
    -- Legendaries
    KazzalaxFujiedasFury          = Item(137053, {15}),
    NajentussVertebrae 			  = Item(137087, {6})
  };
  local I = Item.Warrior.Fury;
-- Rotation Var
  local ShouldReturn; -- Used to get the return string
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Warrior.Commons,
    Fury    = AR.GUISettings.APL.Warrior.Fury
  };


--- APL Action Lists (and Variables)
  -- # CDs
  local function CDs ()
    -- actions.cooldowns+=/rampage,if=talent.massacre.enabled&buff.massacre.react&buff.enrage.remains<1
    if S.Rampage:IsReady() and S.Massacre:IsAvailable() and Player:Buff(S.Massacre) and Player:BuffRemains(S.Enrage) < Player:GCD() then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.cooldowns+=/bloodthirst,if=target.health.pct<20&buff.enrage.remains<1
    if S.Bloodthirst:IsReady() and Target:HealthPercentage() < 20 and Player:BuffRemains(S.Enrage) < Player:GCD() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.cooldowns+=/odyns_fury,if=spell_targets.odyns_fury>1
    if AR.CDsON() and S.OdynsFury:IsReady() and Cache.EnemiesCount[14] > 1 and Player:BuffRemains(S.BattleCry) >= Player:GCD() then
      if AR.Cast(S.OdynsFury) then return ""; end
    end
    -- actions.cooldowns+=/whirlwind,if=spell_targets.whirlwind>4&(buff.enrage.up|cooldown.bloodthirst.remains>1|!rage=100)
    if AR.AoEON() and S.Whirlwind:IsReady() and Cache.EnemiesCount[8] > 4 and (Player:Buff(S.Enrage) or S.Bloodthirst:CooldownRemains() > 1 or not Player:Rage() == 100) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.cooldowns+=/execute
    if S.Execute:IsReady() then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.cooldowns+=/raging_blow,if=buff.enrage.up&talent.inner_rage.enabled
    if S.RagingBlow:IsReady() and Player:Buff(S.Enrage) and S.InnerRage:IsAvailable() then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.cooldowns+=/rampage,if=talent.reckless_abandon.enabled&!talent.frothing_berserker.enabled|(talent.frothing_berserker.enabled&rage>=100)
    if S.Rampage:IsReady() and S.RecklessAbandon:IsAvailable() and not S.FrothingBerserker:IsAvailable() or (S.FrothingBerserker:IsAvailable() and Player:Rage() >= 100) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.cooldowns+=/berserker_rage,if=talent.outburst.enabled&buff.enrage.down&buff.battle_cry.up
    if S.BerserkerRage:IsReady() and S.Outburst:IsAvailable() and not Player:Buff(S.Enrage) and Player:Buff(S.BattleCry) then
      if AR.Cast(S.BerserkerRage) then return ""; end
    end
    -- actions.cooldowns+=/bloodthirst,if=buff.enrage.remains<1&!talent.outburst.enabled
    if S.Bloodthirst:IsReady() and Player:BuffRemains(S.Enrage) < 1 and not S.Outburst:IsAvailable() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.cooldowns+=/odyns_fury
    if AR.CDsON() and S.OdynsFury:IsReady() and Player:BuffRemains(S.BattleCry) >= Player:GCD() then
      if AR.Cast(S.OdynsFury) then return ""; end
    end
    -- actions.cooldowns+=/raging_blow
    if S.RagingBlow:IsReady() then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.cooldowns+=/bloodthirst
    if S.Bloodthirst:IsReady() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.cooldowns+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
    if S.Whirlwind:IsReady() and Player:Buff(S.WreckingBall) and Player:Buff(S.Enrage) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.cooldowns+=/furious_slash
    if S.FuriousSlash:IsReady() then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    return false;
  end

  -- Cleave
  local function Cleave ()
    -- actions.three_targets+=/execute,if=buff.stone_heart.react
    if S.Execute:IsReady() and Player:Buff(S.StoneHeart) then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.three_targets+=/rampage,if=buff.meat_cleaver.up&((buff.enrage.down&!talent.frothing_berserker.enabled)|(rage>=100&talent.frothing_berserker.enabled))|buff.massacre.react
    if S.Rampage:IsReady() and Player:Buff(S.MeatCleaver) and ((not Player:Buff(S.Enrage) and not S.FrothingBerserker:IsAvailable()) or
    (Player:Rage() >= 100 and S.FrothingBerserker:IsAvailable())) or Player:Buff(S.Massacre) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.three_targets+=/raging_blow,if=talent.inner_rage.enabled&(spell_targets.whirlwind=2|(spell_targets.whirlwind=3&!equipped.najentuss_vertebrae))
    if S.RagingBlow:IsReady() and S.InnerRage:IsAvailable() and (Cache.EnemiesCount[8] == 2 or (Cache.EnemiesCount[8] == 3 and not I.NajentussVertebrae:IsEquipped())) then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.three_targets+=/bloodthirst
    if S.Bloodthirst:IsReady() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.three_targets+=/whirlwind
    if AR.AoEON() and S.Whirlwind:IsReady() then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    return false;
  end

  -- # AoE
  local function AoE ()
    -- actions.aoe=bloodthirst,if=buff.enrage.down&rage<90
    if S.Bloodthirst:IsReady() and not Player:Buff(S.Enrage) and Player:Rage() < 90 then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.aoe+=bladestorm,if=buff.enrage.remains>2&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)
    if AR.CDsON() and S.Bladestorm:IsReady() and Player:BuffRemains(S.Enrage) > 2 and Cache.EnemiesCount[8] > 1 then
      if AR.Cast(S.Bladestorm) then return ""; end
    end
    -- actions.aoe+=/whirlwind,if=buff.meat_cleaver.down
    if AR.AoEON() and S.Whirlwind:IsReady() and not Player:Buff(S.MeatCleaver) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.aoe+=/rampage,if=buff.meat_cleaver.up&(buff.enrage.down&!talent.frothing_berserker.enabled|buff.massacre.react|rage>=100)
    if S.Rampage:IsReady() and Player:Buff(S.MeatCleaver) and (not Player:Buff(S.Enrage) and not S.FrothingBerserker:IsAvailable() or Player:Buff(S.Massacre) or Player:Rage() >= 100) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.aoe+=/bloodthirst
    if S.Bloodthirst:IsReady() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.aoe+=/whirlwind
    if AR.AoEON() and S.Whirlwind:IsReady() then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    return false;
  end

  -- # execute
  local function execute ()
    -- actions.execute+=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
    if S.Bloodthirst:IsReady() and I.KazzalaxFujiedasFury:IsEquipped() and (not Player:Buff(S.FujiedasFury) or Player:BuffRemains(S.FujiedasFury) <= Player:GCD() / 2) then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.execute+=/execute,if=artifact.juggernaut.enabled&(!buff.juggernaut.up|buff.juggernaut.remains<2)|buff.stone_heart.react
    if S.Execute:IsReady() and S.Juggernaut:IsAvailable() and (not Player:Buff(S.Juggernaut) or Player:BuffRemains(S.Juggernaut) < 2) or Player:Buff(S.StoneHeart) then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.execute+=/furious_slash,if=talent.frenzy.enabled&buff.frenzy.remains<=2
    if S.FuriousSlash:IsReady() and S.Frenzy:IsAvailable() and Player:BuffRemains(S.FrenzyBuff) <= 2 then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.execute+=/rampage,if=buff.massacre.react&buff.enrage.remains<1
    if S.Rampage:IsReady() and (Player:Buff(S.Massacre) and Player:BuffRemains(S.Enrage) < Player:GCD()) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.execute+=/execute
    if S.Execute:IsReady() or (AC.Tier19_2Pc and Target:TimeToDie() >= 10 and Player:RageTimeToX(25,0) <= S.Bloodthirst:CooldownRemains()) then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.execute+=/bloodthirst
    if S.Bloodthirst:IsReady() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.execute+=/furious_slash,if=set_bonus.tier19_2pc
    if S.FuriousSlash:IsReady() and AC.Tier19_2Pc and Target:TimeToDie() >= 10 then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.execute+=/whirlwind,if=spell_targets.whirlwind=3&buff.wrecking_ball.react&buff.enrage.up
    if AR.AoEON() and S.Whirlwind:IsReady() and Cache.EnemiesCount[8] == 3 and Player:Buff(S.WreckingBall) and Player:Buff(S.Enrage) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.execute+=/raging_blow
    if S.RagingBlow:IsReady() and (not AC.Tier19_2Pc or (AC.Tier19_2Pc and Target:TimeToDie() < 10)) then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.execute+=/furious_slash
    if S.FuriousSlash:IsReady() then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    return false;
  end

  -- # single_target
  local function single_target ()
    -- actions.single_target+=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
    if S.Bloodthirst:IsReady() and I.KazzalaxFujiedasFury:IsEquipped() and (not Player:Buff(S.FujiedasFury) or Player:BuffRemains(S.FujiedasFury) <= Player:GCD()) then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.single_target+=/furious_slash,if=talent.frenzy.enabled&(buff.frenzy.down|buff.frenzy.remains<=2)
    if S.FuriousSlash:IsReady() and S.Frenzy:IsAvailable() and (not Player:Buff(S.FrenzyBuff) or Player:BuffRemains(S.FrenzyBuff) <= 2) then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.single_target+=/raging_blow,if=buff.enrage.up&talent.inner_rage.enabled
    if S.RagingBlow:IsReady() and Player:Buff(S.Enrage) and S.InnerRage:IsAvailable() then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.single_target+=/rampage,if=(buff.enrage.down&!talent.frothing_berserker.enabled)|buff.massacre.react|rage>=100
    if S.Rampage:IsReady() and (not Player:Buff(S.Enrage) and not S.FrothingBerserker:IsAvailable()) or Player:Buff(S.Massacre) or Player:Rage() >= 100 then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.single_target+=/execute,if=buff.stone_heart.react&((talent.inner_rage.enabled&cooldown.raging_blow.remains>1)|buff.enrage.up)
    if S.Execute:IsReady() and Player:Buff(S.StoneHeart) and ((S.InnerRage:IsAvailable() and S.RagingBlow:CooldownRemains() > Player:GCD()) or Player:Buff(S.Enrage))then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.single_target+=/bloodthirst
    if S.Bloodthirst:IsReady() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.single_target+=/raging_blow
    if S.RagingBlow:IsReady() then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.single_target+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
    if S.Whirlwind:IsReady() and Player:Buff(S.WreckingBall) and Player:Buff(S.Enrage) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.single_target+=/furious_slash
    if S.FuriousSlash:IsReady() then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    return false;
  end

-- APL Main
local function APL ()
-- Unit Update
  AC.GetEnemies(8);
  AC.GetEnemies(14);
  Everyone.AoEToggleEnemiesUpdate();

  --- In Combat
  if Everyone.TargetIsValid() then
    -- actions+=/call_action_list,name=cooldowns,if=buff.battle_cry.up
      if Player:Buff(S.BattleCry) then
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      end
    -- actions+=/call_action_list,name=three_targets,if=target.health.pct>20&(spell_targets.whirlwind=3|spell_targets.whirlwind=4)
    if Target:HealthPercentage() > 20 and (Cache.EnemiesCount[8] == 3 or Cache.EnemiesCount[8] == 4) then
        ShouldReturn = Cleave();
        if ShouldReturn then return ShouldReturn; end
      end
    -- actions+=/call_action_list,name=aoe,if=spell_targets.whirlwind>4
      if Cache.EnemiesCount[8] > 4 then
        ShouldReturn = AoE();
        if ShouldReturn then return ShouldReturn; end
      end
    -- actions+=/call_action_list,name=execute,if=target.health.pct<20
      if Target:HealthPercentage() < 20 then
        ShouldReturn = execute ();
        if ShouldReturn then return ShouldReturn; end
      end
    -- actions+=/call_action_list,name=single_target,if=target.health.pct>20
      if Target:HealthPercentage() > 20 then
        ShouldReturn = single_target();
        if ShouldReturn then return ShouldReturn; end
      end
    return;
  end
end
AR.SetAPL(72, APL);

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/charge
-- # This is mostly to prevent cooldowns from being accidentally used during movement.
-- actions+=/run_action_list,name=movement,if=movement.distance>5
-- actions+=/heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)|!raid_event.movement.exists
-- actions+=/potion,name=old_war,if=(target.health.pct<20&buff.battle_cry.up)|target.time_to_die<30
-- actions+=/use_item,name=ring_of_collapsing_futures,if=equipped.ring_of_collapsing_futures&buff.battle_cry.up&buff.enrage.up&!buff.temptation.up
-- actions+=/bloodthirst,if=equipped.kazzalax_fujiedas_fury&buff.fujiedas_fury.down
-- actions+=/dragon_roar,if=(equipped.convergence_of_fates&cooldown.battle_cry.remains<2)|!equipped.convergence_of_fates&(!cooldown.battle_cry.remains<=10|cooldown.battle_cry.remains<2)
-- actions+=/rampage,if=cooldown.battle_cry.remains<4
-- actions+=/battle_cry,if=gcd.remains=0&talent.reckless_abandon.enabled
-- actions+=/battle_cry,if=gcd.remains=0&talent.bladestorm.enabled&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)
-- actions+=/battle_cry,if=gcd.remains=0&buff.dragon_roar.up&(cooldown.bloodthirst.remains=0|buff.enrage.remains>cooldown.bloodthirst.remains)
-- actions+=/avatar,if=buff.battle_cry.remains>6|cooldown.battle_cry.remains<10|(target.time_to_die<(cooldown.battle_cry.remains+10))
-- actions+=/bloodbath,if=buff.dragon_roar.up|(!talent.dragon_roar.enabled&(buff.battle_cry.up|cooldown.battle_cry.remains>40))
-- actions+=/blood_fury,if=buff.battle_cry.up
-- actions+=/berserking,if=buff.battle_cry.up
-- actions+=/arcane_torrent,if=rage<rage.max-40
-- actions+=/run_action_list,name=cooldowns,if=buff.battle_cry.up
-- actions+=/call_action_list,name=three_targets,if=target.health.pct>20&(spell_targets.whirlwind=3|spell_targets.whirlwind=4)
-- actions+=/call_action_list,name=aoe,if=spell_targets.whirlwind>4
-- actions+=/run_action_list,name=execute,if=target.health.pct<20
-- actions+=/run_action_list,name=single_target,if=target.health.pct>20
 
-- actions.movement=heroic_leap
 
-- actions.cooldowns+=/rampage,if=talent.massacre.enabled&buff.massacre.react&buff.enrage.remains<1
-- actions.cooldowns+=/execute,if=cooldown.draught_of_souls.remains<1&buff.juggernaut.remains<3
-- actions.cooldowns+=/bloodthirst,if=target.health.pct<20&buff.enrage.remains<1
-- actions.cooldowns+=/use_item,name=draught_of_souls,if=equipped.draught_of_souls,if=buff.battle_cry.remains>2&buff.enrage.remains>2&((talent.dragon_roar.enabled&buff.dragon_roar.remains>=3)|!talent.dragon_roar.enabled)
-- actions.cooldowns+=/use_item,slot=trinket1,if=buff.battle_cry.up&buff.enrage.up
-- actions.cooldowns+=/use_item,slot=trinket2,if=!equipped.draught_of_souls&buff.battle_cry.up&buff.enrage.up
-- actions.cooldowns+=/odyns_fury,if=spell_targets.odyns_fury>1
-- actions.cooldowns+=/whirlwind,if=spell_targets.whirlwind>4&(buff.enrage.up|cooldown.bloodthirst.remains>1|!rage=100)
-- actions.cooldowns+=/execute
-- actions.cooldowns+=/raging_blow,if=buff.enrage.up&talent.inner_rage.enabled
-- actions.cooldowns+=/rampage,if=talent.reckless_abandon.enabled&!talent.frothing_berserker.enabled|(talent.frothing_berserker.enabled&rage>=100)
-- actions.cooldowns+=/berserker_rage,if=talent.outburst.enabled&buff.enrage.down&buff.battle_cry.up
-- actions.cooldowns+=/bloodthirst,if=buff.enrage.remains<1&!talent.outburst.enabled
-- actions.cooldowns+=/odyns_fury
-- actions.cooldowns+=/raging_blow
-- actions.cooldowns+=/bloodthirst
-- actions.cooldowns+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
-- actions.cooldowns+=/furious_slash
 
-- actions.single_target+=/bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
-- actions.single_target+=/furious_slash,if=talent.frenzy.enabled&(buff.frenzy.down|buff.frenzy.remains<=2)
-- actions.single_target+=/raging_blow,if=buff.enrage.up&talent.inner_rage.enabled
-- actions.single_target+=/rampage,if=(buff.enrage.down&!talent.frothing_berserker.enabled)|buff.massacre.react|rage>=100
-- actions.single_target+=/execute,if=buff.stone_heart.react&((talent.inner_rage.enabled&cooldown.raging_blow.remains>1)|buff.enrage.up)
-- actions.single_target+=/bloodthirst
-- actions.single_target+=/raging_blow
-- actions.single_target+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
-- actions.single_target+=/furious_slash
 
-- actions.execute+=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
-- actions.execute+=/execute,if=artifact.juggernaut.enabled&(!buff.juggernaut.up|buff.juggernaut.remains<2)|buff.stone_heart.react
-- actions.execute+=/furious_slash,if=talent.frenzy.enabled&buff.frenzy.remains<=2
-- actions.execute+=/rampage,if=buff.massacre.react&buff.enrage.remains<1
-- actions.execute+=/execute
-- actions.execute+=/bloodthirst
-- actions.execute+=/furious_slash,if=set_bonus.tier19_2pc
-- actions.execute+=/raging_blow
-- actions.execute+=/furious_slash
 
-- actions.three_targets+=/execute,if=buff.stone_heart.react
-- actions.three_targets+=/rampage,if=buff.meat_cleaver.up&((buff.enrage.down&!talent.frothing_berserker.enabled)|(rage>=100&talent.frothing_berserker.enabled))|buff.massacre.react
-- actions.three_targets+=/raging_blow,if=talent.inner_rage.enabled&(spell_targets.whirlwind=2|(spell_targets.whirlwind=3&!equipped.najentuss_vertebrae))
-- actions.three_targets+=/bloodthirst
-- actions.three_targets+=/whirlwind
 
-- actions.aoe=bloodthirst,if=buff.enrage.down&rage<90
-- actions.aoe+=bladestorm,if=buff.enrage.remains>2&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)
-- actions.aoe+=/whirlwind,if=buff.meat_cleaver.down
-- actions.aoe+=/rampage,if=buff.meat_cleaver.up&(buff.enrage.down&!talent.frothing_berserker.enabled|buff.massacre.react|rage>=100)
-- actions.aoe+=/bloodthirst
-- actions.aoe+=/whirlwind
