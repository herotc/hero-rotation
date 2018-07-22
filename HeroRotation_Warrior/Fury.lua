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
    ExecuteMassacre               = Spell(280735),
    HeroicLeap                    = Spell(6544),
    HeroicThrow                   = Spell(57755),
    RagingBlow                    = Spell(85288),
    Rampage                       = Spell(184367),
    Recklessness                  = Spell(1719),
    VictoryRush                   = Spell(34428),
    Whirlwind                     = Spell(190411),
    WhirlwindBuff                 = Spell(85739),
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
    SuddenDeath                   = Spell(280721),
    SuddenDeathBuff               = Spell(280776),
    SuddenDeathBuffLeg            = Spell(225947),
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
    if HR.CDsON() and S.Siegebreaker:IsReady() and S.Siegebreaker:IsAvailable() and (Player:Buff(S.Recklessness) or S.Recklessness:CooldownRemainsP() > 28 ) then
      if HR.Cast(S.Siegebreaker, Settings.Fury.GCDasOffGCD.Siegebreaker) then return ""; end
    end
    -- actions.single_target+=/rampage,if=buff.recklessness.up|(talent.frothing_berserker.enabled|talent.carnage.enabled&(buff.enrage.remains<gcd|rage>90)|talent.massacre.enabled&(buff.enrage.remains<gcd|rage>90))
    if S.Rampage:IsReady() and (Player:Buff(S.Recklessness) or (S.FrothingBerserker:IsAvailable() or S.Carnage:IsAvailable() and (Player:BuffRemainsP(S.Enrage) < Player:GCD() or Player:Rage() > 90) or S.Massacre:IsAvailable() and (Player:BuffRemainsP(S.Enrage) < Player:GCD() or Player:Rage() > 90))) then
      if HR.Cast(S.Rampage) then return ""; end
    end
    -- actions.single_target+=/execute,if=buff.enrage.up
    if S.Execute:IsReady() and Player:Buff(S.Enrage) then
      if HR.Cast(S.Execute) then return ""; end
    end
    if S.ExecuteMassacre:IsReady() and Player:Buff(S.Enrage) then
      if HR.Cast(S.ExecuteMassacre) then return ""; end
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
      if HR.Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm) then return ""; end
    end
    -- actions.single_target+=/dragon_roar,if=buff.enrage.up&(debuff.siegebreaker.up|!talent.siegebreaker.enabled)
    if HR.CDsON() and S.DragonRoar:IsCastable() and Player:Buff(S.Enrage) and (Target:Debuff(S.SiegebreakerDebuff) or not S.Siegebreaker:IsAvailable()) then
      if HR.Cast(S.DragonRoar, Settings.Fury.GCDasOffGCD.DragonRoar) then return ""; end
    end
    -- actions.single_target+=/raging_blow,if=talent.carnage.enabled|(talent.massacre.enabled&rage<80)|(talent.frothing_berserker.enabled&rage<90)
    if S.RagingBlow:IsReady() and (S.Carnage:IsAvailable() or (S.Massacre:IsAvailable() and Player:Rage() < 80) or (S.FrothingBerserker:IsAvailable() and Player:Rage() < 90)) then
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
  -- Out of Combat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    -- Buff
    if S.BattleShout:IsCastable() and not Player:Buff(S.BattleShout) then
      if HR.Cast(S.BattleShout) then return ""; end
    end
    -- Reset Combat Variables
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
  end
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
  if Settings.Fury.ShowPoPP and I.PotionOfProlongedPower:IsReady() then
    if HR.CastSuggested(I.PotionOfProlongedPower) then return ""; end
  end
  if Settings.Fury.ShowPoOW and I.PotionoftheOldWar:IsReady() then
    if HR.CastSuggested(I.PotionoftheOldWar) then return ""; end
  end
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
    if HR.Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return ""; end
  end
  -- actions+=/whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up
  if HR.AoEON() and S.Whirlwind:IsCastable() and (Cache.EnemiesCount[8] > 1 and not Player:Buff(S.WhirlwindBuff)) then
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

--- Last Update: 07/19/2018

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/charge
-- # This is mostly to prevent cooldowns from being accidentally used during movement.
-- actions+=/run_action_list,name=movement,if=movement.distance>5
-- actions+=/heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)|!raid_event.movement.exists
-- actions+=/potion
-- actions+=/furious_slash,if=talent.furious_slash.enabled&(buff.furious_slash.stack<3|buff.furious_slash.remains<3|(cooldown.recklessness.remains<3&buff.furious_slash.remains<9))
-- actions+=/bloodthirst,if=equipped.kazzalax_fujiedas_fury&(buff.fujiedas_fury.down|remains<2)
-- actions+=/rampage,if=cooldown.recklessness.remains<3
-- actions+=/recklessness
-- actions+=/whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up
-- actions+=/blood_fury,if=buff.recklessness.up
-- actions+=/berserking,if=buff.recklessness.up
-- actions+=/arcane_torrent,if=rage<40&!buff.recklessness.up
-- actions+=/lights_judgment,if=cooldown.recklessness.remains<3
-- actions+=/run_action_list,name=single_target

-- actions.movement=heroic_leap

-- actions.single_target=siegebreaker,if=buff.recklessness.up|cooldown.recklessness.remains>28
-- actions.single_target+=/rampage,if=buff.recklessness.up|(talent.frothing_berserker.enabled|talent.carnage.enabled&(buff.enrage.remains<gcd|rage>90)|talent.massacre.enabled&(buff.enrage.remains<gcd|rage>90))
-- actions.single_target+=/execute,if=buff.enrage.up
-- actions.single_target+=/bloodthirst,if=buff.enrage.down
-- actions.single_target+=/raging_blow,if=charges=2
-- actions.single_target+=/bloodthirst
-- actions.single_target+=/bladestorm,if=prev_gcd.1.rampage&(debuff.siegebreaker.up|!talent.siegebreaker.enabled)
-- actions.single_target+=/dragon_roar,if=buff.enrage.up&(debuff.siegebreaker.up|!talent.siegebreaker.enabled)
-- actions.single_target+=/raging_blow,if=talent.carnage.enabled|(talent.massacre.enabled&rage<80)|(talent.frothing_berserker.enabled&rage<90)
-- actions.single_target+=/furious_slash,if=talent.furious_slash.enabled
-- actions.single_target+=/whirlwind
