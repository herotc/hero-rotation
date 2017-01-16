-- Pull Addon Vars
local addonName, ER = ...;

--- Localize Vars
-- ER
local Unit = ER.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = ER.Spell;
local Item = ER.Item;
-- Lua

--- APL Local Vars
-- Spells
  if not Spell.Warrior then Spell.Warrior = {}; end
  Spell.Warrior.Arms = {
    -- Racials
      Shadowmeld = Spell(58984),
    -- Abilities
      BattleCry = Spell(1719),
      Bladestorm = Spell(227847),
      Cleave = Spell(845),
      ColossusSmash = Spell(167105),
      ColossusSmashDebuff = Spell(208086),
      Execute = Spell(163201),
      MortalStrike = Spell(12294),
      Whirlwind = Spell(1680),
    -- Talents
      Avatar = Spell(107574),
      FocusedRage = Spell(207982),
      Overpower = Spell(7384),
      Ravager = Spell(152277),
      Rend = Spell(772),
    -- Artifact
      Warbreaker = Spell(209577),
    -- Defensive
      CommandingShout = Spell(97462),
      DefensiveStance = Spell(197690),
      DiebytheSword = Spell(118038),
    Victorious = Spell(32216),
      VictoryRush = Spell(34428),
    -- Utility
      Pummel = Spell(6552),
      Shockwave = Spell(46968),
      StormBolt = Spell(107570)
    -- Legendaries
    -- Misc
  };
  local S = Spell.Warrior.Arms;
-- Items
  if not Item.Warrior then Item.Warrior = {}; end
  Item.Warrior.Arms = {
    -- Legendaries
  };
  local I = Item.Warrior.Arms;
-- Rotation Var
  local ShouldReturn, ShouldReturn2; -- Used to get the return string
  local BestUnit, BestUnitTTD; -- Used for cycling
-- GUI Settings
  local Settings = {
    General = ER.GUISettings.General,
    Arms = ER.GUISettings.APL.Warrior.Arms
  };

-- APL Main
local function APL ()
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ DBM Count
      -- Opener
      if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(5) then
        if S.ColossusSmash:IsCastable() then
          if ER.Cast(S.ColossusSmash) then return "Cast"; end
           elseif S.MortalStrike:IsCastable() then
              if ER.Cast(S.MortalStrike) then return "Cast"; end
           elseif S.Whirlwind:IsCastable() and Player:Rage() >= 25 then
              if ER.Cast(S.Whirlwind) then return "Cast"; end
           elseif S.VictoryRush:IsCastable() and Player:Buff(S.Victorious) then
              if ER.Cast(S.VictoryRush) then return "Cast"; end
           end
      end
      return;
    end
  -- In Combat
    -- Unit Update
    ER.GetEnemies(8); -- Whirlwind / Bladestorm
      -- Die by the Sword
      if S.DiebytheSword:IsCastable() and Player:HealthPercentage() <= 50 then
        if ER.Cast(S.DiebytheSword) then return "Cast"; end
      end
      -- Commanding Shout
      if S.CommandingShout:IsCastable() and Player:HealthPercentage() <= 30 then
        if ER.Cast(S.CommandingShout) then return "Cast"; end
      end
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Player:BuffRemains(S.Bladestorm) <= 0.5 then
        -- Victory Rush
        if S.VictoryRush:IsCastable() and Player:Buff(S.Victorious) and Player:HealthPercentage() <= 70 then
           if ER.Cast(S.VictoryRush) then return "Cast"; end
        end
        if Target:IsInRange(5) then
           -- Pummel
           if Settings.General.InterruptEnabled and S.Pummel:IsCastable() and Target:IsInterruptible() then
              if ER.Cast(S.Pummel) then return "Cast Kick"; end
           end
           -- Battle Cry
           if ER.CDsON() and S.BattleCry:IsCastable() and Target:DebuffRemains(S.ColossusSmashDebuff) >= 5 then
              if ER.Cast(S.BattleCry) then return "Cast"; end
           end
           -- Colossus Smash
           if S.ColossusSmash:IsCastable() then
              if ER.Cast(S.ColossusSmash) then return "Cast"; end
           end
           -- Warbreaker
           if S.Warbreaker:IsCastable() and S.ColossusSmash:IsOnCooldown() and not Target:Debuff(S.ColossusSmashDebuff) then
              if ER.Cast(S.Warbreaker) then return "Cast"; end
           end
        end
        -- Blade Storm
        if ER.AoEON() and S.Bladestorm:IsCastable() and ER.Cache.EnemiesCount[8] >= 3 then
           if ER.Cast(S.Bladestorm) then return "Cast"; end
        end
        -- Shockwave
        if ER.AoEON() and S.Shockwave:IsCastable() and ER.Cache.EnemiesCount[8] >= 3 and Target:CanBeStunned(true) then
           if ER.Cast(S.Shockwave) then return "Cast"; end
        end
        if Target:IsInRange(5) then
           if ER.Cache.EnemiesCount[8] <= 3 then
              -- Execute
              if S.Execute:IsCastable() and Target:HealthPercentage() <= 20 then
                if ER.Cast(S.Execute) then return "Cast"; end
              end
              -- Mortal Strike
              if S.MortalStrike:IsCastable() then
                if ER.Cast(S.MortalStrike) then return "Cast"; end
              end
           else
              -- Cleave
              if S.Cleave:IsCastable() then
                if ER.Cast(S.Cleave) then return "Cast"; end
              end
           end
           -- Whirlwind
           if S.Whirlwind:IsCastable() and Player:Rage() >= 65-(Target:Debuff(S.ColossusSmashDebuff) and 40 or 0) then
              if ER.Cast(S.Whirlwind) then return "Cast"; end
           end
           -- Victory Rush
           if S.VictoryRush:IsCastable() and Player:Buff(S.Victorious) then
              if ER.Cast(S.VictoryRush) then return "Cast"; end
           end
        end
    end
end

ER.SetAPL(71, APL);

-- Last Update: 01/13
-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/charge
-- # This is mostly to prevent cooldowns from being accidentally used during movement.
-- actions+=/run_action_list,name=movement,if=movement.distance>5
-- actions+=/heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)|!raid_event.movement.exists
-- actions+=/use_item,name=faulty_countermeasure,if=(spell_targets.whirlwind>1|!raid_event.adds.exists)&((talent.bladestorm.enabled&cooldown.bladestorm.remains=0)|buff.battle_cry.up|target.time_to_die<25)
-- actions+=/potion,name=old_war,if=(target.health.pct<20&buff.battle_cry.up)|target.time_to_die<30
-- actions+=/battle_cry,if=(cooldown.odyns_fury.remains=0&(cooldown.bloodthirst.remains=0|(buff.enrage.remains>cooldown.bloodthirst.remains)))
-- actions+=/avatar,if=buff.battle_cry.up|(target.time_to_die<(cooldown.battle_cry.remains+10))
-- actions+=/bloodbath,if=buff.dragon_roar.up|(!talent.dragon_roar.enabled&(buff.battle_cry.up|cooldown.battle_cry.remains>10))
-- actions+=/blood_fury,if=buff.battle_cry.up
-- actions+=/berserking,if=buff.battle_cry.up
-- actions+=/arcane_torrent,if=rage<rage.max-40
-- actions+=/call_action_list,name=two_targets,if=spell_targets.whirlwind=2|spell_targets.whirlwind=3
-- actions+=/call_action_list,name=aoe,if=spell_targets.whirlwind>3
-- actions+=/call_action_list,name=single_target
-- 
-- actions.aoe=bloodthirst,if=buff.enrage.down|rage<50
-- actions.aoe+=/call_action_list,name=bladestorm
-- actions.aoe+=/odyns_fury,if=buff.battle_cry.up&buff.enrage.up
-- actions.aoe+=/whirlwind,if=buff.enrage.up
-- actions.aoe+=/dragon_roar
-- actions.aoe+=/rampage,if=buff.meat_cleaver.up
-- actions.aoe+=/bloodthirst
-- actions.aoe+=/whirlwind
-- 
-- actions.bladestorm=bladestorm,if=buff.enrage.remains>2&(raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets)
-- 
-- actions.movement=heroic_leap
-- 
-- actions.single_target=bloodthirst,if=buff.fujiedas_fury.up&buff.fujiedas_fury.remains<2
-- actions.single_target+=/execute,if=(artifact.juggernaut.enabled&(!buff.juggernaut.up|buff.juggernaut.remains<2|(buff.sense_death.react&buff.enrage.up)))|buff.stone_heart.react
-- actions.single_target+=/rampage,if=(rage=100&(target.health.pct>=20|(target.health.pct<20&!talent.massacre.enabled&!talent.frothing_berserker.enabled)))|(buff.massacre.react&buff.enrage.remains<1)
-- actions.single_target+=/berserker_rage,if=talent.outburst.enabled&cooldown.odyns_fury.remains=0&buff.enrage.down
-- actions.single_target+=/dragon_roar,if=cooldown.odyns_fury.remains>=10|cooldown.odyns_fury.remains<=3
-- actions.single_target+=/odyns_fury,if=buff.battle_cry.up&buff.enrage.up
-- actions.single_target+=/rampage,if=buff.juggernaut.down&((!talent.frothing_berserker.enabled&buff.enrage.down)|(talent.frothing_berserker.enabled&rage=100)|(talent.reckless_abandon.enabled&cooldown.battle_cry.remains<=gcd.max))
-- actions.single_target+=/furious_slash,if=talent.frenzy.enabled&(buff.frenzy.down|buff.frenzy.remains<=3)
-- actions.single_target+=/raging_blow,if=buff.juggernaut.down&buff.enrage.up
-- actions.single_target+=/whirlwind,if=buff.wrecking_ball.react&buff.enrage.up
-- actions.single_target+=/bloodthirst,if=(talent.frothing_berserker.enabled&buff.enrage.down)|(buff.enrage.remains<2&buff.battle_cry.up&buff.battle_cry.remains<=gcd.max)
-- actions.single_target+=/execute,if=((talent.inner_rage.enabled|!talent.inner_rage.enabled&rage>50)&(!talent.frothing_berserker.enabled|buff.frothing_berserker.up|(cooldown.battle_cry.remains<5&talent.reckless_abandon.enabled)))
-- actions.single_target+=/bloodthirst,if=buff.enrage.down
-- actions.single_target+=/raging_blow,if=buff.enrage.down
-- actions.single_target+=/execute,if=artifact.juggernaut.enabled&(!talent.frothing_berserker.enabled|rage=100)
-- actions.single_target+=/raging_blow
-- actions.single_target+=/bloodthirst
-- actions.single_target+=/furious_slash
-- actions.single_target+=/call_action_list,name=bladestorm
-- actions.single_target+=/bloodbath,if=buff.frothing_berserker.up|(rage>80&!talent.frothing_berserker.enabled)
-- 
-- actions.two_targets=whirlwind,if=buff.meat_cleaver.down
-- actions.two_targets+=/call_action_list,name=bladestorm
-- actions.two_targets+=/rampage,if=buff.enrage.down|(rage=100&buff.juggernaut.down)|buff.massacre.up
-- actions.two_targets+=/bloodthirst,if=buff.enrage.down
-- actions.two_targets+=/odyns_fury,if=buff.battle_cry.up&buff.enrage.up
-- actions.two_targets+=/raging_blow,if=talent.inner_rage.enabled&spell_targets.whirlwind=2
-- actions.two_targets+=/whirlwind,if=spell_targets.whirlwind>2
-- actions.two_targets+=/dragon_roar
-- actions.two_targets+=/bloodthirst
-- actions.two_targets+=/whirlwind
