--- ============================ HEADER ============================
--- ======= LOCALIZE =======
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
  


--- ============================ CONTENT ============================
  --- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local Druid = AR.Commons.Druid;
  -- Spells
  if not Spell.Druid then Spell.Druid = {}; end
  Spell.Druid.Feral = {
    -- Racials
    Shadowmeld          = Spell(58984),
    -- Abilities
    Berserk             = Spell(106951),
    FerociousBite       = Spell(22568),
    PredatorySwiftness  = Spell(69369),
    Prowl               = Spell(5215),
    Rake                = Spell(1822),
    RakeDebuff          = Spell(155722),
    Rip                 = Spell(1079),
    Shred               = Spell(5221),
    Swipe               = Spell(106785),
    Thrash              = Spell(106830),
    TigersFury          = Spell(5217),
    WildCharge          = Spell(102401),
    -- Talents
    BalanceAffinity     = Spell(197488),
    GuardianAffinity    = Spell(217615),
    JaggedWounds        = Spell(202032),
    Incarnation         = Spell(102543),
    RestorationAffinity = Spell(197492),
    -- Artifact
    AshamanesFrenzy     = Spell(210722),
    -- Defensive
    Regrowth            = Spell(8936),
    Renewal             = Spell(108238),
    SurvivalInstincts   = Spell(61336),
    -- Utility
    SkullBash           = Spell(106839),
    -- Shapeshift
    BearForm            = Spell(5487),
    CatForm             = Spell(768),
    MoonkinForm         = Spell(197625),
    TravelForm          = Spell(783)
    -- Legendaries
    
    -- Misc
    
    -- Macros
    
  };
  local S = Spell.Druid.Feral;
  -- Items
  if not Item.Druid then Item.Druid = {}; end
  Item.Druid.Feral = {
    -- Legendaries
    LuffaWrappings = Item(137056, {9})
  };
  local I = Item.Druid.Feral;
  -- Rotation Var
    
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Druid.Commons,
    Feral = AR.GUISettings.APL.Druid.Feral
  };


--- ======= ACTION LISTS =======
  


--- ======= MAIN =======
  local function APL()
    -- Unit Update
    local MeleeRange, AoERadius, RangedRange;
    if S.BalanceAffinity:IsAvailable() then
      -- Have to use the spell itself since Balance Affinity is a special range increase
      MeleeRange = S.Shred;
      AoERadius = I.LuffaWrappings:IsEquipped() and 16.25 or 13;
      RangedRange = 45;
    else
      MeleeRange = "Melee";
      AoERadius = I.LuffaWrappings:IsEquipped() and 10 or 8;
      RangedRange = 40;
    end
    AC.GetEnemies(AoERadius, true); -- Thrash & Swipe
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives
      -- Survival Instincts
      if S.SurvivalInstincts:IsCastable() and not Player:Buff(S.SurvivalInstincts) and Player:HealthPercentage() <= 60 then
        if AR.Cast(S.SurvivalInstincts) then return "Cast"; end
      end
      -- Regrowth
      if S.Regrowth:IsCastable() and Player:Buff(S.PredatorySwiftness) and Player:HealthPercentage() <= 90 then
        if AR.Cast(S.Regrowth) then return "Cast"; end
      end
      -- Renewal
      if S.Renewal:IsCastable() and Player:HealthPercentage() <= 40 then
        if AR.Cast(S.Renewal) then return "Cast"; end
      end
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Prowl
      if not InCombatLockdown() and S.Prowl:CooldownUp() and not Player:IsStealthed() and GetNumLootItems() == 0 and not UnitExists("npc") and AC.OutOfCombatTime() > 1 then
        if AR.Cast(S.Prowl) then return "Cast"; end
      end
      -- Wild Charge
      if S.WildCharge:IsCastable(S.WildCharge) and not Target:IsInRange(8) and not Target:IsInRange(MeleeRange) then
        if AR.Cast(S.WildCharge) then return "Cast"; end
      end
      -- Opener: Rake
      if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(MeleeRange) then
        if S.Rake:IsCastable() then
          if AR.Cast(S.Rake) then return "Cast"; end
        end
      end
      return;
    end
    -- In Combat
    AC.GetEnemies(8, true);
    if Everyone.TargetIsValid() then
      -- Cat Rotation
      if Player:Buff(S.CatForm) then
        -- Skull Bash
        if Settings.General.InterruptEnabled and S.SkullBash:IsCastable(S.SkullBash) and Target:IsInterruptible() then
          if AR.Cast(S.SkullBash) then return "Cast Kick"; end
        end
        if AR.CDsON() and Target:IsInRange(MeleeRange) then
          -- Berserk
          if S.Berserk:IsCastable() then
            if AR.Cast(S.Berserk) then return "Cast"; end
          end
          -- Incarnation: King of the Jungle
          if S.Incarnation:IsCastable() then
            if AR.Cast(S.Incarnation) then return "Cast"; end
          end
          -- Tiger's Fury
          if S.TigersFury:IsCastable() and Player:EnergyDeficit() >= 60 then
            if AR.Cast(S.TigersFury) then return "Cast"; end
          end
        end
        -- Thrash
        if AR.AoEON() and S.Thrash:IsCastable() and Cache.EnemiesCount[AoERadius] >= 3 and Target:TimeToDie() - Target:DebuffRemains(S.Thrash) >= 6 and Target:DebuffRefreshable(S.Thrash, 24 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.3) then
          if AR.Cast(S.Thrash) then return "Cast"; end
        end
        -- Finishers
        if Player:ComboPoints() >= 5 and Target:IsInRange(MeleeRange) then
          -- Rip
          if (Target:HealthPercentage() >= 25 or Player:Level() < 66) and not (Target:DebuffRemains(S.Rip) > 1) and S.Rip:IsCastable() and Target:TimeToDie() - Target:DebuffRemains(S.Rip) >= 10 and Target:DebuffRefreshable(S.Rip, 24 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.3) then
            if AR.Cast(S.Rip) then return "Cast"; end
          end
          -- Ferocious Bite
          if S.FerociousBite:IsCastable() then
            if AR.Cast(S.FerociousBite) then return "Cast"; end
          end
        -- Builders
        else
          if S.AshamanesFrenzy:IsCastable(MeleeRange) and Player:ComboPointsDeficit() >= 3 then
            if AR.Cast(S.AshamanesFrenzy) then return "Cast"; end
          end
          -- Rake
          if S.Rake:IsCastable(MeleeRange) and Target:TimeToDie() - Target:DebuffRemains(S.RakeDebuff) >= 5 and Target:DebuffRefreshable(S.RakeDebuff, 15 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.3) then
            if AR.Cast(S.Rake) then return "Cast"; end
          end
          -- Swipe/Brutal Slash
          if AR.AoEON() and (Cache.EnemiesCount[AoERadius] >= 3 or (not Target:IsInRange(MeleeRange) and Cache.EnemiesCount[AoERadius] >= 1)) then
            if S.Swipe:IsCastable() then
              if AR.Cast(S.Swipe) then return "Cast"; end
            end
          -- Shred
          else
            if S.Shred:IsCastable(MeleeRange) then
              if AR.Cast(S.Shred) then return "Cast"; end
            end
          end
        end
      else
        if S.CatForm:IsCastable(MeleeRange) then
          if AR.Cast(S.CatForm) then return "Cast"; end
        end
      end
    end
  end

  AR.SetAPL(103, APL);


--- ======= SIMC =======
