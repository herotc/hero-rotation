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
