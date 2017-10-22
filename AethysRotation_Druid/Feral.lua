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
  if not Spell.Druid then Spell.Druid = {}; end
  Spell.Druid.Feral = {
    -- Racials
      Shadowmeld = Spell(58984),
    -- Abilities
      FerociousBite = Spell(22568),
      Prowl = Spell(5215),
      PredatorySwiftness = Spell(69369),
      Rake = Spell(1822),
      RakeDebuff = Spell(155722),
      Rip = Spell(1079),
      Shred = Spell(5221),
      Swipe = Spell(106785),
      Thrash = Spell(106830),
      TigersFury = Spell(5217),
      WildCharge = Spell(102401),
    -- Talents
      AstralInfluence = Spell(197524),
      JaggedWounds = Spell(202032),
      Incarnation = Spell(102543),
    -- Artifact
      AshamanesFrenzy = Spell(210722),
    -- Defensive
      Regrowth = Spell(8936),
      Renewal = Spell(108238),
      SurvivalInstincts = Spell(61336),
    -- Utility
      CatForm = Spell(768),
      SkullBash = Spell(106839)
    -- Legendaries
    -- Misc
  };
  local S = Spell.Druid.Feral;
-- Items
  if not Item.Druid then Item.Druid = {}; end
  Item.Druid.Feral = {
    -- Legendaries
  };
  local I = Item.Druid.Feral;
-- Rotation Var
  local ShouldReturn, ShouldReturn2; -- Used to get the return string
  local BestUnit, BestUnitTTD; -- Used for cycling
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Feral = AR.GUISettings.APL.Druid.Feral
  };

local AbilityRange = (Player:Buff(S.AstralInfluence) and 10 or 5)

-- APL Main
local function APL()
  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Prowl
    if not InCombatLockdown() and S.Prowl:CooldownUp() and not Player:IsStealthed() and GetNumLootItems() == 0 and not UnitExists("npc") and AC.OutOfCombatTime() > 1 then
      if AR.Cast(S.Prowl) then return "Cast"; end
    end
    -- Wild Charge
    if Target:IsInRange(20 + AbilityRange) and not Target:IsInRange(AbilityRange) then
      if S.WildCharge:IsCastable() then
        if AR.Cast(S.WildCharge) then return "Cast"; end
      end
    end
    -- Opener: Rake
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(AbilityRange) then
      if S.Rake:IsCastable() then
        if AR.Cast(S.Rake) then return "Cast"; end
      end
    end
    return;
  end
  
  -- In Combat
  AC.GetEnemies(8);
  -- Survival Instincts
  if S.SurvivalInstincts:IsCastable() and not Player:Buff(S.SurvivalInstincts) and Player:HealthPercentage() <= 60 then
    if AR.Cast(S.SurvivalInstincts) then return "Cast Kick"; end
  end
  -- Regrowth
  if S.Regrowth:IsCastable() and Player:Buff(S.PredatorySwiftness) and Player:HealthPercentage() <= 90 then
    if AR.Cast(S.Regrowth) then return "Cast"; end
  end
  -- Renewal
  if S.Renewal:IsCastable() and Player:HealthPercentage() <= 40 then
    if AR.Cast(S.Renewal) then return "Cast"; end
  end
  
  if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
    -- Cat Rotation
    if Player:Buff(S.CatForm) then
      -- Skull Bash
      if Settings.General.InterruptEnabled and Target:IsInRange(AbilityRange) and S.SkullBash:IsCastable() and Target:IsInterruptible() then
        if AR.Cast(S.SkullBash) then return "Cast Kick"; end
      end
      -- Incarnation: King of the Jungle
      if AR.CDsON() and Target:IsInRange(AbilityRange) and S.Incarnation:IsCastable() then
        if AR.Cast(S.Incarnation) then return "Cast"; end
      end
      -- Tiger's Fury
      if AR.CDsON() and Target:IsInRange(AbilityRange) and S.TigersFury:IsCastable() and Player:EnergyDeficit() >= 60 then
        if AR.Cast(S.TigersFury) then return "Cast"; end
      end
      -- Thrash
      if AR.AoEON() and S.Thrash:IsCastable() and Cache.EnemiesCount[8] >= 3 and Target:TimeToDie() - Target:DebuffDuration(S.Thrash) >= and Target:DebuffRefreshable(S.Thrash, 24 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.3) then
        if AR.Cast(S.Thrash) then return "Cast"; end
      end
      -- Finishers
      if Player:ComboPoints() >= 5 and Target:IsInRange(5) then
        -- Rip
        if (Target:HealthPercentage() >= 25 or Player:Level() < 66) and not (Target:DebuffDuration(S.Rip) > 1) and S.Rip:IsCastable() and Target:TimeToDie() - Target:DebuffDuration(S.Rip) >= 10 and Target:DebuffRefreshable(S.Rip, 24 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.3) then
          if AR.Cast(S.Rip) then return "Cast"; end
        end
        -- Ferocious Bite
        if S.FerociousBite:IsCastable() then
          if AR.Cast(S.FerociousBite) then return "Cast"; end
        end
      -- Builders
      else
        if Target:IsInRange(AbilityRange) and S.AshamanesFrenzy:IsCastable() and Player:ComboPointsDeficit() >= 3 then
          if AR.Cast(S.AshamanesFrenzy) then return "Cast"; end
        end
        -- Rake
        if Target:IsInRange(AbilityRange) and S.Rake:IsCastable() and Target:TimeToDie() - Target:DebuffRemains(S.RakeDebuff) >= 5 and Target:DebuffRefreshable(S.RakeRebuff, 15 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.3) then
          if Ar.Cast(S.Rake) then return "Cast"; end
        end
        -- Swipe/Brutal Slash
        if AR.AoEON() and Cache.EnemiesCount[8] >= 3 or (not Target:IsInRange(5) and Cache.EnemiesCount[8] >= 1) then
          if S.Swipe:IsCastable() then
            if AR.Cast(S.Swipe) then return "Cast"; end
          end
        -- Shred
        elseif Target:IsInRange(AbilityRange) then
          if S.Shred:IsCastable() then
            if AR.Cast(S.Shred) then return "Cast"; end
          end
        end
      end
    else
      if Target:IsInRange(AbilityRange) and S.CatForm:IsCastable() then
        if AR.Cast(S.CatForm) then return "Cast"; end
      end
    end
  end
end

AR.SetAPL(103, APL);