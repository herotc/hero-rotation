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
    Bloodthrist                   = Spell(23881),
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
    DraughtofSouls                = Item(140808),
    ConvergenceofFates            = Item(140806),
    -- Legendaries
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
    -- actions.cooldowns=rampage,if=talent.massacre.enabled&buff.massacre.react&buff.enrage.remains<1
    if S.Rampage:IsCastable() and Player:Rage() >= 70 + (S.Massacre:IsAvailable() and 15 or 0) and S.Massacre:IsAvailable() and Player:Buff(S.Massacre) and Player:BuffRemains(S.Enrage) < 1 then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.cooldowns+=/bloodthirst,if=target.health.pct<20&buff.enrage.remains<1
    if S.Bloodthrist:IsCastable() and Target:HealthPercentage() < 20 and Player:BuffRemains(S.Enrage) < 1 then
      if AR.Cast(S.Bloodthrist) then return ""; end
    end
    -- actions.cooldowns+=/execute,if=equipped.draught_of_souls&cooldown.draught_of_souls.remains<1&buff.juggernaut.remains<3
    if S.Execute:IsCastable() and Player:Rage() >= 25 and Target:HealthPercentage() < 20 and (I.DraughtofSouls:IsEquipped(13) or I.DraughtofSouls:IsEquipped(14)) and I.DraughtofSouls:Cooldown() < 1 and Player:BuffRemains(S.Juggernaut) < 3 then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.cooldowns+=/use_item,name=draught_of_souls,if=equipped.draught_of_souls&buff.battle_cry.remains>2&buff.enrage.remains>2&((talent.dragon_roar.enabled&buff.dragon_roar.remains>=3)|!talent.dragon_roar.enabled)
    -- if I:DraughtofSouls:IsUsuable() and I:DraughtofSouls:IsEquipped() and Player:BuffRemains(S.BattleCry) > 2 and Player:BuffRemains(S.Enrage) > 2 and ((S.DragonRoar:IsAvailable() and Player:BuffRemains(S.DragonRoar) >= 3) or not S.DragonRoar:IsAvailable()) then
      -- if AR.Cast(I.DraughtofSouls) then return ""; end
    -- end
    -- TODO : Add item DraughtofSouls
    -- actions.cooldowns+=/odyns_fury,if=spell_targets.odyns_fury>1
    if AR.CDsON() and S.OdynsFury:IsCastable() and Cache.EnemiesCount[14] > 1 then
      if AR.Cast(S.OdynsFury) then return ""; end
    end
    -- actions.cooldowns+=/whirlwind,if=spell_targets.whirlwind>1&buff.meat_cleaver.down
    if AR.AoEON() and S.Whirlwind:IsCastable() and Cache.EnemiesCount[8] > 1 and not Player:Buff(S.MeatCleaver) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.cooldowns+=/execute
    if S.Execute:IsCastable() and Player:Rage() >= 25 and Target:HealthPercentage() < 20 then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.cooldowns+=/raging_blow,if=talent.inner_rage.enabled&buff.enrage.up
    if S.RagingBlow:IsCastable() and S.InnerRage:IsAvailable() and Player:Buff(S.Enrage) then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.cooldowns+=/rampage,if=!talent.frothing_berserker.enabled|(talent.frothing_berserker.enabled&rage>=100)
    if S.Rampage:IsCastable() and (Player:Rage() >= 70 + (S.Massacre:IsAvailable() and 15 or 0) or (S.FrothingBerserker:IsAvailable() and Player:Rage() >= 100 )) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.cooldowns+=/berserker_rage,if=talent.outburst.enabled&buff.enrage.down&buff.battle_cry.up
    if S.BerserkerRage:IsCastable() and S.Outburst:IsAvailable() and not Player:Buff(S.Enrage) and Player:Buff(S.BattleCry) then
      if AR.Cast(S.BerserkerRage) then return ""; end
    end
    -- actions.cooldowns+=/bloodthirst,if=buff.enrage.remains<1&!talent.outburst.enabled
    if S.Bloodthrist:IsCastable() and Player:BuffRemains(S.Enrage) < 1 and not S.Outburst:IsAvailable() then
      if AR.Cast(S.Bloodthrist) then return ""; end
    end
    -- actions.cooldowns+=/raging_blow,if=talent.inner_rage.enabled
    if S.RagingBlow:IsCastable() and S.InnerRage:IsAvailable() then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.cooldowns+=/odyns_fury
    if AR.CDsON() and S.OdynsFury:IsCastable() then
      if AR.Cast(S.OdynsFury) then return ""; end
    end
    -- actions.cooldowns+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
    if S.Whirlwind:IsCastable() and Player:Buff(S.WreckingBall) and Player:Buff(S.Enrage) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.cooldowns+=/raging_blow,if=!talent.inner_rage.enabled
    if S.RagingBlow:IsCastable() and not S.InnerRage:IsAvailable() and Player:Buff(S.Enrage) then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.cooldowns+=/bloodthirst
    if S.Bloodthrist:IsCastable() then
      if AR.Cast(S.Bloodthrist) then return ""; end
    end
    -- actions.cooldowns+=/furious_slash
    if S.FuriousSlash:IsCastable() then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    return false;
  end

  -- # AoE
  local function AoE ()
    -- actions.aoe=bloodthirst,if=buff.enrage.down|rage<50
    if S.Bloodthrist:IsCastable() and (not Player:Buff(S.Enrage) or Player:Rage() < 50) then
      if AR.Cast(S.Bloodthrist) then return ""; end
    end
    -- actions.aoe+=/bladestorm,if=raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>1
    if AR.CDsON() and S.Bladestorm:IsCastable() and Cache.EnemiesCount[8] > 1 then
      if AR.Cast(S.Bladestorm) then return ""; end
    end
    -- actions.aoe+=/whirlwind,if=buff.meat_cleaver.down
    if AR.AoEON() and S.Whirlwind:IsCastable() and not Player:Buff(S.MeatCleaver) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.aoe+=/execute,if=spell_targets.whirlwind<6&talent.massacre.enabled&!buff.massacre.react
    if S.Execute:IsCastable() and Player:Rage() >= 25 and Cache.EnemiesCount[8] < 6 and S.Massacre:IsAvailable() and not Player:Buff(S.Massacre) then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.aoe+=/rampage,if=buff.meat_cleaver.up&(buff.enrage.down&!talent.frothing_berserker.enabled|buff.massacre.react|rage>=100)
    if S.Rampage:IsCastable() and Player:Buff(S.MeatCleaver) and (not Player:Buff(S.Enrage) and not S.FrothingBerserker:IsAvailable() or Player:Buff(S.Massacre) or Player:Rage() >= 100) then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.aoe+=/bloodthirst
    if S.Bloodthrist:IsCastable() then
      if AR.Cast(S.Bloodthrist) then return ""; end
    end
    -- actions.aoe+=/whirlwind
    if AR.AoEON() and S.Whirlwind:IsCastable() then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    return false;
  end

  -- # execute
  local function execute ()
    -- actions.execute=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
    if S.Bloodthrist:IsCastable() and Player:Buff(S.FujiedasFury) and Player:BuffRemains(S.FujiedasFury) < 2 then
      if AR.Cast(S.Bloodthrist) then return ""; end
    end
    -- actions.execute+=/execute,if=artifact.juggernaut.enabled&(!buff.juggernaut.up|buff.juggernaut.remains<2)|buff.stone_heart.react
    if S.Execute:IsCastable() and Player:Rage() >= 25 and S.Juggernaut:IsAvailable() and ((not Player:Buff(S.Juggernaut) or Player:BuffRemains(S.Juggernaut) < 2) or Player:Buff(S.StoneHeart)) then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.execute+=/furious_slash,if=talent.frenzy.enabled&buff.frenzy.remains<=2
    if S.FuriousSlash:IsCastable() and S.Frenzy:IsAvailable() and Player:BuffRemains(S.FrenzyBuff) <= 2 then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.execute+=/rampage,if=buff.massacre.react&buff.enrage.remains<1
    if S.Rampage:IsCastable() and Player:Buff(S.Massacre) and Player:BuffRemains(S.Enrage) < 1 then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.execute+=/execute
    if S.Execute:IsCastable() and Player:Rage() >= 25 then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.execute+=/bloodthirst
    if S.Bloodthrist:IsCastable() then
      if AR.Cast(S.Bloodthrist) then return ""; end
    end
    -- actions.execute+=/whirlwind,if=spell_targets.whirlwind=3&buff.wrecking_ball.react&buff.enrage.up
    if AR.AoEON() and S.Whirlwind:IsCastable() and Cache.EnemiesCount[8] == 3 and Player:Buff(S.WreckingBall) and Player:Buff(S.Enrage) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.execute+=/furious_slash,if=set_bonus.tier19_2pc
    if S.FuriousSlash:IsCastable() and AC.Tier19_2Pc then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.execute+=/raging_blow
    if S.RagingBlow:IsCastable() then
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
    -- actions.single_target=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
    if S.Bloodthrist:IsCastable() and Player:Buff(S.FujiedasFury) and Player:BuffRemains(S.FujiedasFury) < 2 then
      if AR.Cast(S.Bloodthrist) then return ""; end
    end
    -- actions.single_target+=/furious_slash,if=talent.frenzy.enabled&(buff.frenzy.down|buff.frenzy.remains<=2)
    if S.FuriousSlash:IsCastable() and S.Frenzy:IsAvailable() and (not Player:Buff(S.FrenzyBuff) or Player:BuffRemains(S.FrenzyBuff) <= 2 ) then
      if AR.Cast(S.FuriousSlash) then return ""; end
    end
    -- actions.single_target+=/whirlwind,if=spell_targets.whirlwind=3&buff.wrecking_ball.react
    if AR.AoEON() and S.Whirlwind:IsCastable() and Cache.EnemiesCount[8] == 3 and Player:Buff(S.WreckingBall) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.single_target+=/raging_blow,if=talent.inner_rage.enabled&buff.enrage.up
    if S.RagingBlow:IsCastable() and S.InnerRage:IsAvailable() and Player:Buff(S.Enrage) then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.single_target+=/whirlwind,if=spell_targets.whirlwind>1&buff.meat_cleaver.down
    if AR.AoEON() and S.Whirlwind:IsCastable() and Cache.EnemiesCount[8] > 1 and not Player:Buff(S.MeatCleaver) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.single_target+=/rampage,if=(buff.enrage.down&!talent.frothing_berserker.enabled)|buff.massacre.react|rage>=100
    if S.Rampage:IsCastable() and Player:Rage() >= 70 + (S.Massacre:IsAvailable() and 15 or 0) and (not Player:Buff(S.Enrage) and not S.FrothingBerserker:IsAvailable()) or Player:Buff(S.Massacre) or Player:Rage() >= 100 then
      if AR.Cast(S.Rampage) then return ""; end
    end
    -- actions.single_target+=/raging_blow,if=talent.inner_rage.enabled
    if S.RagingBlow:IsCastable() and S.InnerRage:IsAvailable() then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.single_target+=/execute,if=buff.stone_heart.react
    if S.Execute:IsCastable() and Player:Rage() >= 25 and Player:Buff(S.StoneHeart) then
      if AR.Cast(S.Execute) then return ""; end
    end
    -- actions.single_target+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
    if S.Whirlwind:IsCastable() and Player:Buff(S.WreckingBall) and Player:Buff(S.Enrage) then
      if AR.Cast(S.Whirlwind) then return ""; end
    end
    -- actions.single_target+=/bladestorm,if=buff.enrage.remains>2&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>1)
    if AR.CDsON() and S.Bladestorm:IsCastable() and Player:BuffRemains(S.Enrage) > 2 and Cache.EnemiesCount[8] > 1 then
      if AR.Cast(S.Bladestorm) then return ""; end
    end
    -- actions.single_target+=/bloodthirst
    if S.Bloodthrist:IsCastable() then
      if AR.Cast(S.Bloodthrist) then return ""; end
    end
    -- actions.single_target+=/raging_blow,if=!set_bonus.tier19_2pc&!talent.inner_rage.enabled
    if S.RagingBlow:IsCastable() and not AC.Tier19_2Pc and not S.InnerRage:IsAvailable() and Player:Buff(S.Enrage) then
      if AR.Cast(S.RagingBlow) then return ""; end
    end
    -- actions.single_target+=/whirlwind,if=spell_targets.whirlwind>2
    if AR.AoEON() and S.Whirlwind:IsCastable() and Cache.EnemiesCount[8] > 2 then
      if AR.Cast(S.Whirlwind) then return ""; end
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
      AC.GetEnemies(14);
      AR.Commons.AoEToggleEnemiesUpdate();
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ DBM Count

      -- Opener
      if AR.Commons.TargetIsValid() then
        if not Target:IsInRange(8) and Target:IsInRange(25) and S.Charge:IsCastable() then
          if AR.Cast(S.Charge) then return ""; end
        end
        if Target:IsInRange(5) then
          if S.Bloodthrist:IsCastable() then
            if AR.Cast(S.Bloodthrist) then return ""; end
          end
        end
      end
      return;
    end
  --- In Combat
  if AR.Commons.TargetIsValid() then
    -- actions+=/potion,name=old_war,if=(target.health.pct<20&buff.battle_cry.up)|target.time_to_die<30
    -- actions+=/use_item,name=ring_of_collapsing_futures,if=equipped.ring_of_collapsing_futures&buff.battle_cry.up&buff.enrage.up&!buff.temptation.up
    -- actions+=/dragon_roar,if=(equipped.convergence_of_fates&cooldown.battle_cry.remains<2)|!equipped.convergence_of_fates&(!cooldown.battle_cry.remains<=10|cooldown.battle_cry.remains<2)
    if AR.CDsON() and S.DragonRoar:IsCastable() and (((I.ConvergenceofFates:IsEquipped(13) or I.ConvergenceofFates:IsEquipped(14)) and S.BattleCry:Cooldown() < 2) or (not (I.ConvergenceofFates:IsEquipped(13) or I.ConvergenceofFates:IsEquipped(14)) and (S.BattleCry:Cooldown() > 10 or S.BattleCry:Cooldown() < 2 ))) then
      if AR.Cast(S.DragonRoar) then return ""; end
    end
    -- actions+=/battle_cry,if=gcd.remains=0&!talent.dragon_roar.enabled&(!equipped.convergence_of_fates|!talent.bloodbath.enabled|!cooldown.bloodbath.remains|cooldown.bloodbath.remains>=10)
    -- NOTE: Delete gcd.remains=0 for display BattleCry at offgcd.
    if AR.CDsON() and S.BattleCry:IsCastable() and not S.DragonRoar:IsAvailable() and ((not I.ConvergenceofFates:IsEquipped(13) or I.ConvergenceofFates:IsEquipped(14)) and not S.Bloodbath:IsAvailable() or S.Bloodthrist:Cooldown() or S.Bloodthrist:Cooldown() >= 10) then
      if AR.Cast(S.BattleCry, Settings.Fury.OffGCDasOffGCD.BattleCry) then return ""; end
    end
    -- actions+=/battle_cry,if=gcd.remains=0&buff.dragon_roar.up&(cooldown.bloodthirst.remains=0|buff.enrage.remains>cooldown.bloodthirst.remains)
    -- NOTE: Delete gcd.remains=0 for display BattleCry at offgcd.
    if AR.CDsON() and S.BattleCry:IsCastable() and Player:Buff(S.DragonRoar) and (S.Bloodthrist:Cooldown() == 0 or Player:BuffRemains(S.Enrage) > S.Bloodthrist:Cooldown()) then
      if AR.Cast(S.BattleCry, Settings.Fury.OffGCDasOffGCD.BattleCry) then return ""; end
    end
    -- actions+=/avatar,if=buff.battle_cry.up|(target.time_to_die<(cooldown.battle_cry.remains+10))
    if AR.CDsON() and S.Avatar:IsCastable() and (Player:Buff(S.BattleCry) or (Target:TimeToDie() < S.BattleCry:Cooldown() + 10)) then
      if AR.Cast(S.Avatar, Settings.Fury.OffGCDasOffGCD.Avatar) then return ""; end
    end
    -- actions+=/bloodbath,if=buff.dragon_roar.up|!talent.dragon_roar.enabled&buff.battle_cry.up
    if AR.CDsON() and S.Bloodbath:IsCastable() and (Player:Buff(S.DragonRoar) or (not S.DragonRoar:IsAvailable() and Player:Buff(S.BattleCry))) then
      if AR.Cast(S.Bloodbath) then return ""; end
    end
    -- actions+=/blood_fury,if=buff.battle_cry.up
    if AR.CDsON() and S.BloodFury:IsCastable() and Player:Buff(S.BattleCry) then
      if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.BloodFury) then return ""; end
    end
    -- actions+=/berserking,if=buff.battle_cry.up
    if AR.CDsON() and S.Berserking:IsCastable() and Player:Buff(S.BattleCry) then
      if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Berserking) then return ""; end
    end
    -- actions+=/arcane_torrent,if=rage<rage.max-40
    if AR.CDsON() and S.ArcaneTorrent:IsCastable() and Player:Rage() < Player:RageMax() - 40 then
      if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    -- actions+=/call_action_list,name=cooldowns,if=buff.battle_cry.up
      if Player:Buff(S.BattleCry) then
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      end
    -- actions+=/call_action_list,name=aoe,if=spell_targets.whirlwind>3
      if Cache.EnemiesCount[8] > 3 then
        ShouldReturn = AoE();
        if ShouldReturn then return ShouldReturn; end
      end
    -- actions+=/call_action_list,name=execute,if=target.health.pct<20
      if Target:HealthPercentage() < 20 then
        ShouldReturn = execute();
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

-- Last Update: 03/06/2017
-- actions+=/battle_cry,if=gcd.remains=0&!talent.dragon_roar.enabled&(!equipped.convergence_of_fates|!talent.bloodbath.enabled|!cooldown.bloodbath.remains|cooldown.bloodbath.remains>=10)
-- actions+=/battle_cry,if=gcd.remains=0&buff.dragon_roar.up&(cooldown.bloodthirst.remains=0|buff.enrage.remains>cooldown.bloodthirst.remains)
-- NOTE: Delete gcd.remains=0 for display BattleCry at offgcd.

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,type=countless_armies
-- actions.precombat+=/food,type=azshari_salad
-- actions.precombat+=/augmentation,type=defiled
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion,name=old_war

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/charge
-- # This is mostly to prevent cooldowns from being accidentally used during movement.
-- actions+=/run_action_list,name=movement,if=movement.distance>5
-- actions+=/heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)|!raid_event.movement.exists
-- actions+=/potion,name=old_war,if=(target.health.pct<20&buff.battle_cry.up)|target.time_to_die<30
-- actions+=/use_item,name=ring_of_collapsing_futures,if=equipped.ring_of_collapsing_futures&buff.battle_cry.up&buff.enrage.up&!buff.temptation.up
-- actions+=/dragon_roar,if=(equipped.convergence_of_fates&cooldown.battle_cry.remains<2)|!equipped.convergence_of_fates&(!cooldown.battle_cry.remains<=10|cooldown.battle_cry.remains<2)
-- actions+=/battle_cry,if=gcd.remains=0&!talent.dragon_roar.enabled&(!equipped.convergence_of_fates|!talent.bloodbath.enabled|!cooldown.bloodbath.remains|cooldown.bloodbath.remains>=10)
-- actions+=/battle_cry,if=gcd.remains=0&buff.dragon_roar.up&(cooldown.bloodthirst.remains=0|buff.enrage.remains>cooldown.bloodthirst.remains)
-- actions+=/avatar,if=buff.battle_cry.up|(target.time_to_die<(cooldown.battle_cry.remains+10))
-- actions+=/bloodbath,if=buff.dragon_roar.up|!talent.dragon_roar.enabled&buff.battle_cry.up
-- actions+=/blood_fury,if=buff.battle_cry.up
-- actions+=/berserking,if=buff.battle_cry.up
-- actions+=/arcane_torrent,if=rage<rage.max-40
-- actions+=/call_action_list,name=cooldowns,if=buff.battle_cry.up
-- actions+=/call_action_list,name=aoe,if=spell_targets.whirlwind>3
-- actions+=/call_action_list,name=execute,if=target.health.pct<20
-- actions+=/call_action_list,name=single_target,if=target.health.pct>20

-- actions.aoe=bloodthirst,if=buff.enrage.down|rage<50
-- actions.aoe+=/bladestorm,if=raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>1
-- actions.aoe+=/whirlwind,if=buff.meat_cleaver.down
-- actions.aoe+=/execute,if=spell_targets.whirlwind<6&talent.massacre.enabled&!buff.massacre.react
-- actions.aoe+=/rampage,if=buff.meat_cleaver.up&(buff.enrage.down&!talent.frothing_berserker.enabled|buff.massacre.react|rage>=100)
-- actions.aoe+=/bloodthirst
-- actions.aoe+=/whirlwind

-- actions.cooldowns=rampage,if=talent.massacre.enabled&buff.massacre.react&buff.enrage.remains<1
-- actions.cooldowns+=/bloodthirst,if=target.health.pct<20&buff.enrage.remains<1
-- actions.cooldowns+=/execute,if=equipped.draught_of_souls&cooldown.draught_of_souls.remains<1&buff.juggernaut.remains<3
-- actions.cooldowns+=/use_item,name=draught_of_souls,if=equipped.draught_of_souls&buff.battle_cry.remains>2&buff.enrage.remains>2&((talent.dragon_roar.enabled&buff.dragon_roar.remains>=3)|!talent.dragon_roar.enabled)
-- actions.cooldowns+=/odyns_fury,if=spell_targets.odyns_fury>1
-- actions.cooldowns+=/whirlwind,if=spell_targets.whirlwind>1&buff.meat_cleaver.down
-- actions.cooldowns+=/execute
-- actions.cooldowns+=/raging_blow,if=talent.inner_rage.enabled&buff.enrage.up
-- actions.cooldowns+=/rampage,if=!talent.frothing_berserker.enabled|(talent.frothing_berserker.enabled&rage>=100)
-- actions.cooldowns+=/berserker_rage,if=talent.outburst.enabled&buff.enrage.down&buff.battle_cry.up
-- actions.cooldowns+=/bloodthirst,if=buff.enrage.remains<1&!talent.outburst.enabled
-- actions.cooldowns+=/raging_blow,if=talent.inner_rage.enabled
-- actions.cooldowns+=/odyns_fury
-- actions.cooldowns+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
-- actions.cooldowns+=/raging_blow,if=!talent.inner_rage.enabled
-- actions.cooldowns+=/bloodthirst
-- actions.cooldowns+=/furious_slash

-- actions.execute=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
-- actions.execute+=/execute,if=artifact.juggernaut.enabled&(!buff.juggernaut.up|buff.juggernaut.remains<2)|buff.stone_heart.react
-- actions.execute+=/furious_slash,if=talent.frenzy.enabled&buff.frenzy.remains<=2
-- actions.execute+=/rampage,if=buff.massacre.react&buff.enrage.remains<1
-- actions.execute+=/execute
-- actions.execute+=/bloodthirst
-- actions.execute+=/whirlwind,if=spell_targets.whirlwind=3&buff.wrecking_ball.react&buff.enrage.up
-- actions.execute+=/furious_slash,if=set_bonus.tier19_2pc
-- actions.execute+=/raging_blow
-- actions.execute+=/furious_slash

-- actions.movement=heroic_leap

-- actions.single_target=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
-- actions.single_target+=/furious_slash,if=talent.frenzy.enabled&(buff.frenzy.down|buff.frenzy.remains<=2)
-- actions.single_target+=/whirlwind,if=spell_targets.whirlwind=3&buff.wrecking_ball.react
-- actions.single_target+=/raging_blow,if=talent.inner_rage.enabled&buff.enrage.up
-- actions.single_target+=/whirlwind,if=spell_targets.whirlwind>1&buff.meat_cleaver.down
-- actions.single_target+=/rampage,if=(buff.enrage.down&!talent.frothing_berserker.enabled)|buff.massacre.react|rage>=100
-- actions.single_target+=/raging_blow,if=talent.inner_rage.enabled
-- actions.single_target+=/execute,if=buff.stone_heart.react
-- actions.single_target+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
-- actions.single_target+=/bladestorm,if=buff.enrage.remains>2&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>1)
-- actions.single_target+=/bloodthirst
-- actions.single_target+=/raging_blow,if=!set_bonus.tier19_2pc&!talent.inner_rage.enabled
-- actions.single_target+=/whirlwind,if=spell_targets.whirlwind>2
-- actions.single_target+=/furious_slash