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
    MassacreBuff                  = Spell(206316),
    Outburst                      = Spell(206320),
    RecklessAbandon               = Spell(202751),
    WreckingBall                  = Spell(215570),
    WreckingBallTalent            = Spell(215569),
    -- Artifact
    Juggernaut                    = Spell(980),
    OdynsFury                     = Spell(205545),
    -- Defensive
    -- Utility
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
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Warrior.Commons,
    Fury    = AR.GUISettings.APL.Warrior.Fury
  };


--- APL Action Lists (and Variables)
  -- # AoE
  local function AoE ()
    -- actions.aoe=bloodthirst,if=buff.enrage.down&rage<90
    if S.Bloodthirst:IsCastable() and not Player:Buff(S.Enrage) and Player:Rage() < 90 then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.aoe+=bladestorm,if=buff.enrage.remains>2&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)
    if AR.CDsON() and S.Bladestorm:IsCastable() and Player:BuffRemainsP(S.Enrage) > 2 and Cache.EnemiesCount[8] > 1 then
      if AR.Cast(S.Bladestorm) then return ""; end
    end
    -- actions.aoe+=/whirlwind,if=buff.meat_cleaver.down
    if AR.AoEON() and S.Whirlwind:IsCastable() and not Player:Buff(S.MeatCleaver) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.aoe+=/rampage,if=buff.meat_cleaver.up&(buff.enrage.down&!talent.frothing_berserker.enabled|buff.massacre.react|rage>=100)
    if S.Rampage:IsReady() and Player:BuffP(S.MeatCleaver) and (not Player:BuffP(S.Enrage) and not S.FrothingBerserker:IsAvailable() or Player:BuffP(S.MassacreBuff) or Player:Rage() >= 100) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.aoe+=/bloodthirst
    if S.Bloodthirst:IsCastable() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.aoe+=/whirlwind
    if AR.AoEON() and S.Whirlwind:IsCastable() then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    return false;
  end
  -- # CDs
  local function CDs ()
    -- actions.cooldowns=rampage,if=buff.massacre.react&buff.enrage.remains<1
    if S.Rampage:IsReady() and S.Massacre:IsAvailable() and Player:BuffP(S.MassacreBuff) and Player:BuffRemainsP(S.Enrage) < 1 then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.cooldowns+=/bloodthirst,if=target.health.pct<20&buff.enrage.remains<1
    if S.Bloodthirst:IsCastable() and Target:HealthPercentage() < 20 and Player:BuffRemainsP(S.Enrage) < Player:GCD() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.cooldowns+=/execute
    if S.Execute:IsReady() then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.cooldowns+=/raging_blow,if=talent.inner_rage.enabled&buff.enrage.up
    if S.RagingBlow:IsReady() and S.InnerRage:IsAvailable() and Player:BuffP(S.Enrage) then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.cooldowns+=/rampage,if=(rage>=100&talent.frothing_berserker.enabled&!set_bonus.tier21_4pc)|set_bonus.tier21_4pc|!talent.frothing_berserker.enabled
    if S.Rampage:IsReady() and (Player:Rage() >= 100 and S.FrothingBerserker:IsAvailable() and not AC.Tier21_4Pc) or AC.Tier21_4Pc or not S.FrothingBerserker:IsAvailable() then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.cooldowns+=/odyns_fury,if=buff.enrage.up&(cooldown.raging_blow.remains>0|!talent.inner_rage.enabled)
    if AR.CDsON() and S.OdynsFury:IsCastable() and Player:BuffP(S.Enrage) and (S.RagingBlow:CooldownRemainsP() > 0 or not S.InnerRage:IsAvailable()) then
      if AR.Cast(S.OdynsFury) then return ""; end
    end
    -- actions.cooldowns+=/berserker_rage,if=talent.outburst.enabled&buff.enrage.down&buff.battle_cry.up
    if S.BerserkerRage:IsCastable() and S.Outburst:IsAvailable() and not Player:Buff(S.Enrage) and Player:BuffP(S.BattleCry) then
      if AR.Cast(S.BerserkerRage) then return ""; end
    end
    -- actions.cooldowns+=/bloodthirst,if=(buff.enrage.remains<1&!talent.outburst.enabled)|!talent.inner_rage.enabled
    if S.Bloodthirst:IsCastable() and ((Player:BuffRemainsP(S.Enrage) < 1 and not S.Outburst:IsAvailable()) or not S.InnerRage:IsAvailable()) then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.cooldowns+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
    -- add S.WreckingBallTalent:IsAvailable() for buff.wrecking_ball.react
    if S.Whirlwind:IsCastable() and S.WreckingBallTalent:IsAvailable() and Player:BuffP(S.WreckingBall) and Player:BuffP(S.Enrage) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.cooldowns+=/raging_blow
    if S.RagingBlow:IsReady() then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.cooldowns+=/bloodthirst
    if S.Bloodthirst:IsCastable() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.cooldowns+=/furious_slash
    if S.FuriousSlash:IsCastable() then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    return false;
  end

  -- Cleave
  local function Cleave ()
    -- actions.three_targets+=/execute,if=buff.stone_heart.react
    if S.Execute:IsReady() and Player:BuffP(S.StoneHeart) then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.three_targets+=/rampage,if=buff.meat_cleaver.up&((buff.enrage.down&!talent.frothing_berserker.enabled)|(rage>=100&talent.frothing_berserker.enabled))|buff.massacre.react
    if S.Rampage:IsReady() and Player:BuffP(S.MeatCleaver) and ((not Player:Buff(S.Enrage) and not S.FrothingBerserker:IsAvailable()) or
    (Player:Rage() >= 100 and S.FrothingBerserker:IsAvailable())) or Player:BuffP(S.MassacreBuff) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.three_targets+=/raging_blow,if=talent.inner_rage.enabled&(spell_targets.whirlwind=2|(spell_targets.whirlwind=3&!equipped.najentuss_vertebrae))
    if S.RagingBlow:IsReady() and S.InnerRage:IsAvailable() and (Cache.EnemiesCount[8] == 2 or (Cache.EnemiesCount[8] == 3 and not I.NajentussVertebrae:IsEquipped())) then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.three_targets+=/bloodthirst
    if S.Bloodthirst:IsCastable() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.three_targets+=/whirlwind
    if AR.AoEON() and S.Whirlwind:IsCastable() then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    return false;
  end



  -- # execute
  local function execute ()
    -- actions.execute+=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
    if S.Bloodthirst:IsCastable() and I.KazzalaxFujiedasFury:IsEquipped() and (not Player:BuffP(S.FujiedasFury) or Player:BuffRemainsP(S.FujiedasFury) <= Player:GCD() / 2) then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.execute+=/execute,if=artifact.juggernaut.enabled&(!buff.juggernaut.up|buff.juggernaut.remains<2)|buff.stone_heart.react
    if S.Execute:IsReady() and S.Juggernaut:IsAvailable() and (not Player:BuffP(S.Juggernaut) or Player:BuffRemainsP(S.Juggernaut) < 2) or Player:BuffP(S.StoneHeart) then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.execute+=/furious_slash,if=talent.frenzy.enabled&buff.frenzy.remains<=2
    if S.FuriousSlash:IsCastable() and S.Frenzy:IsAvailable() and Player:BuffRemainsP(S.FrenzyBuff) <= 2 then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.execute+=/rampage,if=buff.massacre.react&buff.enrage.remains<1
    if S.Rampage:IsReady() and (Player:BuffP(S.MassacreBuff) and Player:BuffRemainsP(S.Enrage) < Player:GCD()) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.execute+=/execute
    if S.Execute:IsReady() or (AC.Tier19_2Pc and Target:TimeToDie() >= 10 and Player:RageTimeToX(25,0) <= S.Bloodthirst:CooldownRemainsP()) then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.execute+=/odyns_fury
    if S.OdynsFury:IsCastable() then
      if AR.Cast(S.OdynsFury) then return ""; end
    end
    -- actions.execute+=/bloodthirst
    if S.Bloodthirst:IsCastable() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.execute+=/furious_slash,if=set_bonus.tier19_2pc
    if S.FuriousSlash:IsCastable() and AC.Tier19_2Pc and Target:TimeToDie() >= 10 then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.execute+=/raging_blow
    if S.RagingBlow:IsReady() and (not AC.Tier19_2Pc or (AC.Tier19_2Pc and Target:TimeToDie() < 10)) then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.execute+=/furious_slash
    if S.FuriousSlash:IsCastable() then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    return false;
  end

  -- # single_target
  local function single_target ()
    -- actions.single_target+=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
    if S.Bloodthirst:IsCastable() and I.KazzalaxFujiedasFury:IsEquipped() and (not Player:BuffP(S.FujiedasFury) or Player:BuffRemainsP(S.FujiedasFury) <= Player:GCD()) then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.single_target+=/furious_slash,if=talent.frenzy.enabled&(buff.frenzy.down|buff.frenzy.remains<=2)
    if S.FuriousSlash:IsCastable() and S.Frenzy:IsAvailable() and (not Player:Buff(S.FrenzyBuff) or Player:BuffRemainsP(S.FrenzyBuff) <= 2) then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.single_target+=/raging_blow,if=buff.enrage.up&talent.inner_rage.enabled
    if S.RagingBlow:IsReady() and Player:BuffP(S.Enrage) and S.InnerRage:IsAvailable() then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.single_target+=/rampage,if=target.health.pct>21&(rage>=100|!talent.frothing_berserker.enabled)&(((cooldown.battle_cry.remains>5|cooldown.bloodbath.remains>5)&!talent.carnage.enabled)|((cooldown.battle_cry.remains>3|cooldown.bloodbath.remains>3)&talent.carnage.enabled))|buff.massacre.react
    if S.Rampage:IsReady() and (Target:HealthPercentage() > 21 
      and (Player:Rage() >= 100 or not S.FrothingBerserker:IsAvailable()) 
      and (((S.BattleCry:CooldownRemainsP() > 5 or S.Bloodbath:CooldownRemainsP() > 5) and not S.Carnage:IsAvailable()) 
        or ((S.BattleCry:CooldownRemainsP() > 3 or S.Bloodbath:CooldownRemainsP() > 3) and S.Carnage:IsAvailable())) 
      or Player:BuffP(S.MassacreBuff)) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.single_target+=/execute,if=buff.stone_heart.react&((talent.inner_rage.enabled&cooldown.raging_blow.remains>1)|buff.enrage.up)
    if S.Execute:IsReady() and Player:BuffP(S.StoneHeart) and ((S.InnerRage:IsAvailable() and S.RagingBlow:CooldownRemainsP() > Player:GCD()) or Player:BuffP(S.Enrage))then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.single_target+=/bloodthirst
    if S.Bloodthirst:IsCastable() then
      if AR.Cast(S.Bloodthirst) then return ""; end
    end
    -- actions.single_target+=/furious_slash,if=set_bonus.tier19_2pc&!talent.inner_rage.enabled
    if S.FuriousSlash:IsCastable() and AC.Tier19_2Pc and not S.InnerRage:IsAvailable() then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.single_target+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
    -- add S.WreckingBallTalent:IsAvailable() for buff.wrecking_ball.react
    if S.Whirlwind:IsCastable() and S.WreckingBallTalent:IsAvailable() and Player:BuffP(S.WreckingBall) and Player:BuffP(S.Enrage) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.single_target+=/raging_blow
    if S.RagingBlow:IsReady() then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.single_target+=/furious_slash
    if S.FuriousSlash:IsCastable() then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    return false;
  end

-- APL Main
local function APL ()
-- Unit Update
  AC.GetEnemies(8);
  AC.GetEnemies(10);
  Everyone.AoEToggleEnemiesUpdate();

  --- In Combat
  if Everyone.TargetIsValid() then
  -- actions+=/charge
  if S.Charge:IsCastable() and Target:IsInRange(S.Charge) then
    if AR.Cast(S.Charge) then return ""; end
  end
  -- actions+=/potion,name=old_war,if=buff.battle_cry.up&(buff.avatar.up|!talent.avatar.enabled)
  if Settings.Fury.ShowPoOW and I.PotionoftheOldWar:IsReady() and Player:BuffP(S.BattleCry) and (Player:BuffP(S.Avatar) or not S.Avatar:IsAvailable()) then
    if AR.CastSuggested(I.PotionoftheOldWar) then return ""; end
  end
  -- actions+=/dragon_roar,if=(equipped.convergence_of_fates&cooldown.battle_cry.remains<2)|!equipped.convergence_of_fates&(!cooldown.battle_cry.remains<=10|cooldown.battle_cry.remains<2)|(talent.bloodbath.enabled&(cooldown.bloodbath.remains<1|buff.bloodbath.up))
  if AR.CDsON() and S.DragonRoar:IsCastable() 
    and ((I.ConvergenceofFates:IsEquipped() and S.BattleCry:CooldownRemainsP() < 2) 
      or not I.ConvergenceofFates:IsEquipped() and (S.BattleCry:CooldownRemainsP() > 10 or S.BattleCry:CooldownRemainsP() < 2) 
      or (not S.Bloodbath:IsAvailable() and (S.Bloodbath:CooldownRemainsP() < 1 or Player:BuffP(S.Bloodbath)))) then
    if AR.Cast(S.DragonRoar, Settings.Fury.GCDasOffGCD.DragonRoar) then return ""; end
  end
  -- actions+=/rampage,if=cooldown.battle_cry.remains<1&cooldown.bloodbath.remains<1&target.health.pct>20
  if S.Rampage:IsReady() and S.BattleCry:CooldownRemainsP() < 1 and S.Bloodbath:CooldownRemainsP() < 1 and Target:HealthPercentage() > 20 then
    if AR.CastQueue(S.Rampage, S.BattleCry) then return ""; end
  end
  -- actions+=/furious_slash,if=talent.frenzy.enabled&(buff.frenzy.stack<3|buff.frenzy.remains<3|(cooldown.battle_cry.remains<1&buff.frenzy.remains<9))
  if S.FuriousSlash:IsCastable() and S.Frenzy:IsAvailable() 
    and (Player:BuffStack(S.FrenzyBuff) < 3 or Player:BuffRemainsP(S.FrenzyBuff) < 3 
      or (S.BattleCry:CooldownRemainsP() < 1 and Player:BuffRemainsP(S.FrenzyBuff) < 9)) then
    if AR.Cast(S.FuriousSlash) then return ""; end
  end
  -- actions+=/use_item,name=umbral_moonglaives,if=equipped.umbral_moonglaives&(cooldown.battle_cry.remains>gcd&cooldown.battle_cry.remains<2|cooldown.battle_cry.remains=0)
  if I.UmbralMoonglaives:IsReady() and I.UmbralMoonglaives:IsEquipped() 
    and (S.BattleCry:CooldownRemainsP() > Player:GCD() 
      and S.BattleCry:CooldownRemainsP() < 2 
        or S.BattleCry:CooldownRemainsP() == 0) then
    if AR.Cast(I.UmbralMoonglaives, Settings.Fury.OffGCDasOffGCD.UmbralMoonglaives) then return ""; end
  end
  -- actions+=/bloodthirst,if=equipped.kazzalax_fujiedas_fury&buff.fujiedas_fury.down
  if S.Bloodthirst:IsCastable() and I.KazzalaxFujiedasFury:IsEquipped() and not Player:BuffP(S.FujiedasFury) then
    if AR.Cast(S.Bloodthirst) then return ""; end
  end
  if AR.CDsON() then
    -- actions+=/avatar,if=((buff.battle_cry.remains>5|cooldown.battle_cry.remains<12)&target.time_to_die>80)|((target.time_to_die<40)&(buff.battle_cry.remains>6|cooldown.battle_cry.remains<12|(target.time_to_die<20)))
    if S.Avatar:IsCastable() 
      and (((Player:BuffRemainsP(S.BattleCry) > 5 or S.BattleCry:CooldownRemainsP() < 12) and Target:TimeToDie() > 80) 
      or ((Target:TimeToDie() < 40) and Player:BuffRemainsP(S.BattleCry) > 6 
        or S.BattleCry:CooldownRemainsP() < 12 
        or (Target:TimeToDie() < 20))) then
      if AR.Cast(S.Avatar, Settings.Commons.OffGCDasOffGCD.Avatar) then return ""; end
    end
    -- actions+=/battle_cry,if=gcd.remains=0&talent.reckless_abandon.enabled&!talent.bloodbath.enabled&(equipped.umbral_moonglaives&(prev_off_gcd.umbral_moonglaives|(trinket.cooldown.remains>3&trinket.cooldown.remains<90))|!equipped.umbral_moonglaives)
    if S.BattleCry:IsCastable() 
      and (S.RecklessAbandon:IsAvailable() and not S.Bloodbath:IsAvailable() 
      and (I.UmbralMoonglaives:IsEquipped() 
        and (Player:PrevOffGCDP(1, S.UmbralMoonglaives) 
        or (S.UmbralMoonglaives:CooldownRemainsP() > 3 and S.UmbralMoonglaives:CooldownRemainsP() < 90))) 
      or not I.UmbralMoonglaives:IsEquipped()) then
      if AR.Cast(S.BattleCry, Settings.Commons.OffGCDasOffGCD.BattleCry) then return ""; end
    end
    -- actions+=/battle_cry,if=gcd.remains=0&talent.bladestorm.enabled&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)
    if S.BattleCry:IsCastable() and S.Bladestorm:IsAvailable() then
      if AR.Cast(S.BattleCry, Settings.Commons.OffGCDasOffGCD.BattleCry) then return ""; end
    end
    -- actions+=/battle_cry,if=gcd.remains=0&buff.dragon_roar.up&(cooldown.bloodthirst.remains=0|buff.enrage.remains>cooldown.bloodthirst.remains)
    if S.BattleCry:IsCastable() and Player:BuffP(S.DragonRoar) and (S.Bloodthirst:CooldownRemainsP() == 0 or Player:BuffRemainsP(S.Enrage) > S.Bloodthirst:CooldownRemainsP()) then
      if AR.Cast(S.BattleCry, Settings.Commons.OffGCDasOffGCD.BattleCry) then return ""; end
    end
    -- actions+=/battle_cry,if=(gcd.remains=0|gcd.remains<=0.4&prev_gcd.1.rampage)&(cooldown.bloodbath.remains=0|buff.bloodbath.up|!talent.bloodbath.enabled|(target.time_to_die<12))
    -- actions+=/battle_cry,if=(gcd.remains=0|gcd.remains<=0.4&prev_gcd.1.rampage)&(cooldown.bloodbath.remains=0|buff.bloodbath.up|!talent.bloodbath.enabled|(target.time_to_die<12))&(equipped.umbral_moonglaives&(prev_off_gcd.umbral_moonglaives|(trinket.cooldown.remains>3&trinket.cooldown.remains<90))|!equipped.umbral_moonglaives)
    if S.BattleCry:IsCastable() 
      and (Player:GCDRemains() == 0 or (Player:GCDRemains() <= 0.4 and Player:PrevGCDP(1, S.Rampage))) 
      and (S.Bloodbath:CooldownRemainsP() == 0 or Player:BuffP(S.Bloodbath) 
        or not S.Bloodbath:IsAvailable() 
        or (Target:TimeToDie() < 12)) 
      and (I.UmbralMoonglaives:IsEquipped() 
        and (Player:PrevOffGCDP(1, S.UmbralMoonglaives) 
        or (S.UmbralMoonglaives:CooldownRemainsP() > 3 and S.UmbralMoonglaives:CooldownRemainsP() < 90))) 
      or not I.UmbralMoonglaives:IsEquipped() then
      if AR.Cast(S.BattleCry, Settings.Commons.OffGCDasOffGCD.BattleCry) then return ""; end
    end
    -- actions+=/bloodbath,if=buff.battle_cry.up|(target.time_to_die<14)|(cooldown.battle_cry.remains<2&prev_gcd.1.rampage)
    if S.Bloodbath:IsCastable() and (Player:BuffP(S.BattleCry) or (Target:TimeToDie() < 14) or (S.BattleCry:CooldownRemainsP() < 2 and Player:PrevGCDP(1, S.Rampage))) then
      if AR.Cast(S.Bloodbath, Settings.Fury.OffGCDasOffGCD.Bloodbath) then return ""; end
    end
    -- actions+=/blood_fury,if=buff.battle_cry.up
    if S.BloodFury:IsCastable() and Player:BuffP(S.BattleCry) then
      if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- actions+=/berserking,if=(buff.battle_cry.up&(buff.avatar.up|!talent.avatar.enabled))|(buff.battle_cry.up&target.time_to_die<40)
    if S.Berserking:IsCastable() and ((Player:BuffP(S.BattleCry) 
      and (Player:BuffP(S.Avatar) or not S.Avatar:IsAvailable())) 
        or (Player:BuffP(S.BattleCry) and Target:TimeToDie() < 40)) then
      if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- actions+=/arcane_torrent,if=rage<rage.max-40
    if S.ArcaneTorrent:IsCastable() and Player:Rage() < Player:RageMax() - 40 then
      if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
  end
  -- # Action list
    -- actions+=/run_action_list,name=cooldowns,if=buff.battle_cry.up&spell_targets.whirlwind=1
      if Player:BuffP(S.BattleCry) and Cache.EnemiesCount[8] == 1 then
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      end
    -- actions+=/run_action_list,name=three_targets,if=target.health.pct>20&(spell_targets.whirlwind=3|spell_targets.whirlwind=4)
    if Target:HealthPercentage() > 20 and (Cache.EnemiesCount[8] == 3 or Cache.EnemiesCount[8] == 4) then
        ShouldReturn = Cleave();
        if ShouldReturn then return ShouldReturn; end
      end
    -- actions+=/run_action_list,name=aoe,if=spell_targets.whirlwind>4
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
