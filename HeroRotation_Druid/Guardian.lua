--- ============================ HEADER ============================
--- ======= LOCALIZE =======
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
  local tableinsert = table.insert;


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = HR.Commons.Everyone;
  local Druid = HR.Commons.Druid;
  -- Spells
  if not Spell.Druid then Spell.Druid = {}; end
  Spell.Druid.Guardian = {
    -- Racials
    
    -- Abilities
    FrenziedRegeneration = Spell(22842),
    GoreBuff             = Spell(93622),
    GoryFur              = Spell(201671),
    Ironfur              = Spell(192081),
    Mangle               = Spell(33917),
    Maul                 = Spell(6807),
    Moonfire             = Spell(8921),
    MoonfireDebuff       = Spell(164812),
    Regrowth             = Spell(8936),
    SwipeBear            = Spell(213771),
    SwipeCat             = Spell(106785),
    ThrashBear           = Spell(77758),
    ThrashBearDebuff     = Spell(192090),
    ThrashCat            = Spell(106830),
    -- Talents
    BalanceAffinity      = Spell(197488),
    BloodFrenzy          = Spell(203962),
    Brambles             = Spell(203953),
    BristlingFur         = Spell(155835),
    Earthwarden          = Spell(203974),
    EarthwardenBuff      = Spell(203975),
    FeralAffinity        = Spell(202155),
    GalacticGuardian     = Spell(203964),
    GalacticGuardianBuff = Spell(213708),
    GuardianofElune      = Spell(155578),
    GuardianofEluneBuff  = Spell(213680),
    Incarnation          = Spell(102558),
    LunarBeam            = Spell(204066),
    Pulverize            = Spell(80313),
    PulverizeBuff        = Spell(158792),
    RestorationAffinity  = Spell(197492),
    SouloftheForest      = Spell(158477),
    -- Artifact
    RageoftheSleeper     = Spell(200851),
    -- Defensive
    SurvivalInstincts    = Spell(61336),
    Barkskin             = Spell(22812),
    -- Utility
    Growl                = Spell(6795),
    SkullBash            = Spell(106839),
    -- Affinity
    FerociousBite        = Spell(22568),
    HealingTouch         = Spell(5185),
    LunarStrike          = Spell(197628),
    Rake                 = Spell(1822),
    RakeDebuff           = Spell(155722),
    Rejuvenation         = Spell(774),
    Rip                  = Spell(1079),
    Shred                = Spell(5221),
    SolarWrath           = Spell(197629),
    Starsurge            = Spell(197626),
    Sunfire              = Spell(197630),
    SunfireDebuff        = Spell(164815),
    Swiftmend            = Spell(18562),
    -- Shapeshift
    BearForm             = Spell(5487),
    CatForm              = Spell(768),
    MoonkinForm          = Spell(197625),
    TravelForm           = Spell(783),
    -- Legendaries
    
    -- Misc
    
    -- Macros
    
  };
  local S = Spell.Druid.Guardian;
  -- Items
  if not Item.Druid then Item.Druid = {}; end
  Item.Druid.Guardian = {
    -- Legendaries
    EkowraithCreatorofWorlds = Item(137015, {5}),
    LuffaWrappings = Item(137056, {9})
  };
  local I = Item.Druid.Guardian;
  -- Rotation Var
  
  -- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Commons = HR.GUISettings.APL.Druid.Commons,
    Guardian = HR.GUISettings.APL.Druid.Guardian
  };


--- ======= ACTION LISTS =======
  


--- ======= MAIN =======
  local function APL ()
    -- Unit Update
    local MeleeRange, AoERadius, RangedRange;
    if S.BalanceAffinity:IsAvailable() then
      -- Have to use the spell itself since Balance Affinity is a special range increase
      MeleeRange = S.Mangle;
      if I.EkowraithCreatorofWorlds:IsEquipped() then
        AoERadius = I.LuffaWrappings:IsEquipped() and 20.9 or 16.75;
      else
        AoERadius = I.LuffaWrappings:IsEquipped() and 16.25 or 13;
      end
      RangedRange = S.Moonfire;
    else
      MeleeRange = "Melee";
      AoERadius = I.LuffaWrappings:IsEquipped() and 10 or 8;
      RangedRange = 40;
    end
    HL.GetEnemies(AoERadius, true); -- Thrash & Swipe
    Everyone.AoEToggleEnemiesUpdate();
    -- Defensives
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if Everyone.TargetIsValid() then
        if Player:Buff(S.CatForm) then
          -- Shred
          if S.Shred:IsCastable(MeleeRange) then
              if HR.Cast(S.Shred) then return "Cast"; end
          end
          return;
        end
        if Player:Buff(S.BearForm) then
          if S.Mangle:IsCastable(MeleeRange) then
            if HR.Cast(S.Mangle) then return ""; end
          end
          if S.ThrashBear:IsCastable(AoERadius, true) then
            if HR.Cast(S.ThrashBear) then return ""; end
          end
          if S.SwipeBear:IsCastable(AoERadius, true) then
            if HR.Cast(S.SwipeBear) then return ""; end
          end
        end
        if S.Moonfire:IsCastable(RangedRange) then
          if HR.Cast(S.Moonfire) then return ""; end
        end
      end
      return;
    end
    -- In Combat
    if Everyone.TargetIsValid() then
      if Player:Buff(S.CatForm) then
        -- Thrash
        -- Note: Due to an in-game bug, you cannot apply a new thrash if there is the bear one.
        if S.ThrashCat:IsCastable() and Cache.EnemiesCount[AoERadius] >= 1 and Target:DebuffRefreshable(S.ThrashCat, 4.5) and not Target:Debuff(S.ThrashBearDebuff) then
          if HR.Cast(S.ThrashCat) then return "Cast"; end
        end
        -- Rip
        if S.Rip:IsCastable(MeleeRange) and Player:ComboPoints() >= 5 and Target:DebuffRefreshable(S.Rip, 7.2) then
          if HR.Cast(S.Rip) then return "Cast"; end
        end
        -- Rake
        if S.Rake:IsCastable(MeleeRange) and Target:DebuffRefreshable(S.RakeDebuff, 4.5) then
          if HR.Cast(S.Rake) then return "Cast"; end
        end
        -- Swipe
        if S.SwipeCat:IsCastable() and Cache.EnemiesCount[AoERadius] >= 2 then
          if HR.Cast(S.SwipeCat) then return "Cast"; end
        end
        -- Shred
        if S.Shred:IsCastable(MeleeRange) then
            if HR.Cast(S.Shred) then return "Cast"; end
        end
        return;
      end
      if Player:Buff(S.BearForm) then
        local UseMaul = not HR.CDsON() and Cache.EnemiesCount[AoERadius] < 5 and Player:HealthPercentage() >= 60;
        local IsTanking = Player:IsTankingAoE(AoERadius) or Player:IsTanking(Target);
        -- # Executed every time the actor is available.
        -- actions=auto_attack
        -- actions+=/blood_fury
        -- actions+=/berserking
        -- actions+=/arcane_torrent
        -- actions+=/use_item,slot=trinket2
        -- actions+=/incarnation
        -- actions+=/rage_of_the_sleeper
        -- actions+=/lunar_beam

        -- actions+=/frenzied_regeneration,if=incoming_damage_5s%health.max>=0.5|health<=health.max*0.4
        if not UseMaul and S.FrenziedRegeneration:IsCastable() and Player:Rage() > 10
          and Player:HealthPercentage() <= 60 and not Player:Buff(S.FrenziedRegeneration) and not Player:HealingAbsorbed() then
          if HR.Cast(S.FrenziedRegeneration, {true, false}) then return ""; end
        end
        if not UseMaul and S.Ironfur:IsCastable() and Player:Rage() >= S.Ironfur:Cost() + 1
          and ( ( IsTanking and ( not Player:Buff(S.Ironfur) or ( Player:BuffStack(S.Ironfur) < 2 and ( Player:Buff(S.GoryFur) or Player:BuffRefreshableP(S.Ironfur, 2.4) ) ) ) )
            or Player:Rage() >= 85 or Player:ActiveMitigationNeeded() ) then
          if HR.Cast(S.Ironfur, {true, false}) then return ""; end
        end

        if S.Moonfire:IsCastable(RangedRange) and not Target:IsInRange(MeleeRange) and Target:DebuffRefreshableP(S.MoonfireDebuff, 0) then
          if HR.Cast(S.Moonfire) then return ""; end
        end

        -- Get aggro on units near
        local Tanks = {};
        local Others = {};
        for _, ThisUnit in pairs(IsInRaid() and Unit.Raid or Unit.Party) do
          tableinsert(UnitGroupRolesAssigned(ThisUnit.UnitID) == "TANK" and Tanks or Others, ThisUnit);
        end
        local UnitsNotTankedCount = 0;
        for _, ThisUnit in pairs(Cache.Enemies[AoERadius]) do
          for _, ThisPlayer in pairs(Others) do
            if ThisPlayer:IsTanking(ThisUnit, 1) then
              UnitsNotTankedCount = UnitsNotTankedCount + 1;
            end
          end
        end
        if UnitsNotTankedCount > 0 then
          if S.ThrashBear:IsCastable() then
            if HR.Cast(S.ThrashBear) then return ""; end
          end
          if S.SwipeBear:IsCastable() then
            if HR.Cast(S.SwipeBear) then return ""; end
          end
        end

        if S.Moonfire:IsCastable(RangedRange) and Player:Buff(S.Incarnation) and Target:DebuffRefreshableP(S.MoonfireDebuff, 4.8) then
          if HR.Cast(S.Moonfire) then return ""; end
        end
        if UseMaul and S.Maul:IsCastable(MeleeRange) and Player:Rage() >= 85 then
          if HR.Cast(S.Maul) then return ""; end
        end
        if S.ThrashBear:IsCastable(AoERadius, true) and Cache.EnemiesCount[AoERadius] >= 2 then
          if HR.Cast(S.ThrashBear) then return ""; end
        end
        if S.Mangle:IsCastable(MeleeRange) then
          if HR.Cast(S.Mangle) then return ""; end
        end
        if S.ThrashBear:IsCastable(AoERadius, true) then
          if HR.Cast(S.ThrashBear) then return ""; end
        end
        -- actions+=/pulverize,if=buff.pulverize.up=0|buff.pulverize.remains<=6
        if S.Pulverize:IsCastable(MeleeRange) and Target:DebuffStack(S.ThrashBearDebuff) >= 2 and Player:BuffRefreshableP(S.PulverizeBuff, 6) then
          if HR.Cast(S.Pulverize) then return ""; end
        end
        if S.Moonfire:IsCastable(RangedRange) and (Player:Buff(S.GalacticGuardianBuff) or Target:DebuffRefreshableP(S.MoonfireDebuff, 4.8)) then
          if HR.Cast(S.Moonfire) then return ""; end
        end
        if S.ThrashBear:IsCastable() and Cache.EnemiesCount[AoERadius] >= 1 then
          if HR.Cast(S.ThrashBear) then return ""; end
        end
        if UseMaul and S.Maul:IsCastable(MeleeRange) and Player:Rage() >= 70 then
          if HR.Cast(S.Maul) then return ""; end
        end
        if S.SwipeBear:IsCastable() and Cache.EnemiesCount[AoERadius] >= 1 then
          if HR.Cast(S.SwipeBear) then return ""; end
        end
        if S.Moonfire:IsCastable(RangedRange) then
          if HR.Cast(S.Moonfire) then return ""; end
        end
        return;
      end
    end
  end

  HR.SetAPL(104, APL);


--- ======= SIMC =======
--- Last Update: 09/24/2017

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/blood_fury
-- actions+=/berserking
-- actions+=/arcane_torrent
-- actions+=/use_item,slot=trinket2
-- actions+=/incarnation
-- actions+=/rage_of_the_sleeper
-- actions+=/lunar_beam
-- actions+=/frenzied_regeneration,if=incoming_damage_5s%health.max>=0.5|health<=health.max*0.4
-- actions+=/bristling_fur,if=buff.ironfur.stack=1|buff.ironfur.down
-- actions+=/ironfur,if=(buff.ironfur.up=0)|(buff.gory_fur.up=1)|(rage>=80)
-- actions+=/moonfire,if=buff.incarnation.up=1&dot.moonfire.remains<=4.8
-- actions+=/thrash_bear,if=buff.incarnation.up=1&dot.thrash.remains<=4.5
-- actions+=/mangle
-- actions+=/thrash_bear
-- actions+=/pulverize,if=buff.pulverize.up=0|buff.pulverize.remains<=6
-- actions+=/moonfire,if=buff.galactic_guardian.up=1&(!ticking|dot.moonfire.remains<=4.8)
-- actions+=/moonfire,if=buff.galactic_guardian.up=1
-- actions+=/moonfire,if=dot.moonfire.remains<=4.8
-- actions+=/swipe_bear
