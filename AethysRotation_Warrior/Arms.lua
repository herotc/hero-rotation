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
    General = AR.GUISettings.General,
    Arms = AR.GUISettings.APL.Warrior.Arms
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
          if AR.Cast(S.ColossusSmash) then return "Cast"; end
           elseif S.MortalStrike:IsCastable() then
              if AR.Cast(S.MortalStrike) then return "Cast"; end
           elseif S.Whirlwind:IsCastable() and Player:Rage() >= 25 then
              if AR.Cast(S.Whirlwind) then return "Cast"; end
           elseif S.VictoryRush:IsCastable() and Player:Buff(S.Victorious) then
              if AR.Cast(S.VictoryRush) then return "Cast"; end
           end
      end
      return;
    end
  -- In Combat
    -- Unit Update
    AC.GetEnemies(8); -- Whirlwind / Bladestorm
      -- Die by the Sword
      if S.DiebytheSword:IsCastable() and Player:HealthPercentage() <= 50 then
        if AR.Cast(S.DiebytheSword) then return "Cast"; end
      end
      -- Commanding Shout
      if S.CommandingShout:IsCastable() and Player:HealthPercentage() <= 30 then
        if AR.Cast(S.CommandingShout) then return "Cast"; end
      end
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Player:BuffRemains(S.Bladestorm) <= 0.5 then
        -- Victory Rush
        if S.VictoryRush:IsCastable() and Player:Buff(S.Victorious) and Player:HealthPercentage() <= 70 then
           if AR.Cast(S.VictoryRush) then return "Cast"; end
        end
        if Target:IsInRange(5) then
           -- Pummel
           if Settings.General.InterruptEnabled and S.Pummel:IsCastable() and Target:IsInterruptible() then
              if AR.Cast(S.Pummel) then return "Cast Kick"; end
           end
           -- Battle Cry
           if AR.CDsON() and S.BattleCry:IsCastable() and Target:DebuffRemains(S.ColossusSmashDebuff) >= 5 then
              if AR.Cast(S.BattleCry) then return "Cast"; end
           end
           -- Colossus Smash
           if S.ColossusSmash:IsCastable() then
              if AR.Cast(S.ColossusSmash) then return "Cast"; end
           end
           -- Warbreaker
           if S.Warbreaker:IsCastable() and S.ColossusSmash:IsOnCooldown() and not Target:Debuff(S.ColossusSmashDebuff) then
              if AR.Cast(S.Warbreaker) then return "Cast"; end
           end
        end
        -- Blade Storm
        if AR.AoEON() and S.Bladestorm:IsCastable() and Cache.EnemiesCount[8] >= 3 then
           if AR.Cast(S.Bladestorm) then return "Cast"; end
        end
        -- Shockwave
        if AR.AoEON() and S.Shockwave:IsCastable() and Cache.EnemiesCount[8] >= 3 and Target:CanBeStunned(true) then
           if AR.Cast(S.Shockwave) then return "Cast"; end
        end
        if Target:IsInRange(5) then
           if Cache.EnemiesCount[8] <= 3 then
              -- Execute
              if S.Execute:IsCastable() and Target:HealthPercentage() <= 20 then
                if AR.Cast(S.Execute) then return "Cast"; end
              end
              -- Mortal Strike
              if S.MortalStrike:IsCastable() then
                if AR.Cast(S.MortalStrike) then return "Cast"; end
              end
           else
              -- Cleave
              if S.Cleave:IsCastable() then
                if AR.Cast(S.Cleave) then return "Cast"; end
              end
           end
           -- Whirlwind
           if S.Whirlwind:IsCastable() and Player:Rage() >= 65-(Target:Debuff(S.ColossusSmashDebuff) and 40 or 0) then
              if AR.Cast(S.Whirlwind) then return "Cast"; end
           end
           -- Victory Rush
           if S.VictoryRush:IsCastable() and Player:Buff(S.Victorious) then
              if AR.Cast(S.VictoryRush) then return "Cast"; end
           end
        end
    end
end

AR.SetAPL(71, APL);

-- Last Update: 01/19/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,type=countless_armies
-- actions.precombat+=/food,type=fishbrul_special
-- actions.precombat+=/augmentation,type=defiled
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion,name=old_war

-- # Executed every time the actor is available.
-- actions=charge
-- actions+=/auto_attack
-- actions+=/potion,name=old_war,if=buff.avatar.up&buff.battle_cry.up&debuff.colossus_smash.up|target.time_to_die<=26
-- actions+=/blood_fury,if=buff.battle_cry.up|target.time_to_die<=16
-- actions+=/berserking,if=buff.battle_cry.up|target.time_to_die<=11
-- actions+=/arcane_torrent,if=buff.battle_cry_deadly_calm.down&rage.deficit>40&cooldown.battle_cry.remains
-- actions+=/battle_cry,if=gcd.remains<0.25&cooldown.avatar.remains>=10&(buff.shattered_defenses.up|cooldown.warbreaker.remains>7&cooldown.colossus_smash.remains>7|cooldown.colossus_smash.remains&debuff.colossus_smash.remains>gcd)|!cooldown.colossus_smash.remains<gcd|target.time_to_die<=7
-- actions+=/avatar,if=gcd.remains<0.25&(buff.battle_cry.up|cooldown.battle_cry.remains<15)|target.time_to_die<=20
-- actions+=/use_item,name=draught_of_souls,if=equipped.draught_of_souls&((prev_gcd.1.mortal_strike|cooldown.mortal_strike.remains>=3)&buff.battle_cry.remains>=3&debuff.colossus_smash.up&buff.avatar.remains>=3)
-- actions+=/use_item,name=kiljaedens_burning_wish,if=equipped.kiljaedens_burning_wish&debuff.colossus_smash.up
-- actions+=/heroic_leap,if=(debuff.colossus_smash.down|debuff.colossus_smash.remains<2)&cooldown.colossus_smash.remains&equipped.weight_of_the_earth|!equipped.weight_of_the_earth&debuff.colossus_smash.up
-- actions+=/rend,if=remains<gcd
-- actions+=/focused_rage,if=buff.battle_cry_deadly_calm.remains>cooldown.focused_rage.remains&(buff.focused_rage.stack<3|cooldown.mortal_strike.remains)
-- actions+=/colossus_smash,if=cooldown_react&debuff.colossus_smash.remains<gcd
-- actions+=/warbreaker,if=debuff.colossus_smash.remains<gcd
-- actions+=/ravager
-- actions+=/overpower,if=buff.overpower.react
-- actions+=/run_action_list,name=cleave,if=spell_targets.whirlwind>=2&talent.sweeping_strikes.enabled
-- actions+=/run_action_list,name=aoe,if=spell_targets.whirlwind>=5&!talent.sweeping_strikes.enabled
-- actions+=/run_action_list,name=execute,target_if=target.health.pct<=20&spell_targets.whirlwind<5
-- actions+=/run_action_list,name=single,if=target.health.pct>20

-- actions.aoe=mortal_strike,if=cooldown_react
-- actions.aoe+=/execute,if=buff.stone_heart.react
-- actions.aoe+=/colossus_smash,if=cooldown_react&buff.shattered_defenses.down&buff.precise_strikes.down
-- actions.aoe+=/warbreaker,if=buff.shattered_defenses.down
-- actions.aoe+=/whirlwind,if=talent.fervor_of_battle.enabled&(debuff.colossus_smash.up|rage.deficit<50)&(!talent.focused_rage.enabled|buff.battle_cry_deadly_calm.up|buff.cleave.up)
-- actions.aoe+=/rend,if=remains<=duration*0.3
-- actions.aoe+=/bladestorm
-- actions.aoe+=/cleave
-- actions.aoe+=/execute,if=rage>90
-- actions.aoe+=/whirlwind,if=rage>=40
-- actions.aoe+=/shockwave
-- actions.aoe+=/storm_bolt

-- actions.cleave=mortal_strike
-- actions.cleave+=/execute,if=buff.stone_heart.react
-- actions.cleave+=/colossus_smash,if=buff.shattered_defenses.down&buff.precise_strikes.down
-- actions.cleave+=/warbreaker,if=buff.shattered_defenses.down
-- actions.cleave+=/focused_rage,if=rage>100|buff.battle_cry_deadly_calm.up
-- actions.cleave+=/whirlwind,if=talent.fervor_of_battle.enabled&(debuff.colossus_smash.up|rage.deficit<50)&(!talent.focused_rage.enabled|buff.battle_cry_deadly_calm.up|buff.cleave.up)
-- actions.cleave+=/rend,if=remains<=duration*0.3
-- actions.cleave+=/bladestorm
-- actions.cleave+=/cleave
-- actions.cleave+=/whirlwind,if=rage>40|buff.cleave.up
-- actions.cleave+=/shockwave
-- actions.cleave+=/storm_bolt

-- actions.execute=mortal_strike,if=cooldown_react&buff.battle_cry.up&buff.focused_rage.stack=3
-- # actions.execute+=/heroic_charge,if=rage.deficit>=40&(!cooldown.heroic_leap.remains|swing.mh.remains>1.2)
-- #Remove the # above to run out of melee and charge back in for rage.
-- actions.execute+=/execute,if=buff.battle_cry_deadly_calm.up
-- actions.execute+=/colossus_smash,if=cooldown_react&buff.shattered_defenses.down
-- actions.execute+=/execute,if=buff.shattered_defenses.up&(rage>=17.6|buff.stone_heart.react)
-- actions.execute+=/mortal_strike,if=cooldown_react&equipped.archavons_heavy_hand&rage<60|talent.in_for_the_kill.enabled&buff.shattered_defenses.down
-- actions.execute+=/execute,if=buff.shattered_defenses.down
-- actions.execute+=/bladestorm,interrupt=1,if=raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets

-- actions.single=colossus_smash,if=cooldown_react&buff.shattered_defenses.down&(buff.battle_cry.down|buff.battle_cry.up&buff.battle_cry.remains>=gcd|buff.corrupted_blood_of_zakajz.remains>=gcd)
-- # actions.single+=/heroic_charge,if=rage.deficit>=40&(!cooldown.heroic_leap.remains|swing.mh.remains>1.2)&buff.battle_cry.down
-- #Remove the # above to run out of melee and charge back in for rage.
-- actions.single+=/focused_rage,if=!buff.battle_cry_deadly_calm.up&buff.focused_rage.stack<3&!cooldown.colossus_smash.up&(rage>=50|debuff.colossus_smash.down|cooldown.battle_cry.remains<=8)|cooldown.battle_cry.remains<=8&cooldown.battle_cry.remains>0&rage>100
-- actions.single+=/mortal_strike,if=cooldown.battle_cry.remains>8|!buff.battle_cry.remains>(gcd.max*2)&buff.focused_rage.stack<3|buff.battle_cry.remains<=gcd
-- actions.single+=/execute,if=buff.stone_heart.react
-- actions.single+=/whirlwind,if=spell_targets.whirlwind>1|talent.fervor_of_battle.enabled
-- actions.single+=/slam,if=spell_targets.whirlwind=1&!talent.fervor_of_battle.enabled
-- actions.single+=/bladestorm,interrupt=1,if=raid_event.adds.in>90|!raid_event.adds.exists|spell_targets.bladestorm_mh>desired_targets
