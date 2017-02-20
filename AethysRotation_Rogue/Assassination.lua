--- Localize Vars
-- Addon
local addonName, addonTable = ...;
-- AethysCore
local AC = AethysCore;
local Cache = AethysCore_Cache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;
-- AethysRotation
local AR = AethysRotation;
-- Lua
local pairs = pairs;


--- APL Local Vars
-- Spells
  if not Spell.Rogue then Spell.Rogue = {}; end
  Spell.Rogue.Assassination = {
    -- Racials
    ArcaneTorrent                 = Spell(25046),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    -- Abilities
    Envenom                       = Spell(32645),
    FanofKnives                   = Spell(51723),
    Garrote                       = Spell(703),
    KidneyShot                    = Spell(408),
    Mutilate                      = Spell(1329),
    PoisonedKnife                 = Spell(185565),
    Rupture                       = Spell(1943),
    Stealth                       = Spell(1784),
    Vanish                        = Spell(1856),
    Vendetta                      = Spell(79140),
    -- Talents
    Alacrity                      = Spell(193539),
    AlacrityBuff                  = Spell(193538),
    Anticipation                  = Spell(114015),
    DeathFromAbove                = Spell(152150),
    DeeperStratagem               = Spell(193531),
    ElaboratePlanning             = Spell(193640),
    ElaboratePlanningBuff         = Spell(193641),
    Exsanguinate                  = Spell(200806),
    Hemorrhage                    = Spell(16511),
    MarkedforDeath                = Spell(137619),
    MasterPoisoner                = Spell(196864),
    Nightstalker                  = Spell(14062),
    ShadowFocus                   = Spell(108209),
    Subterfuge                    = Spell(108208),
    Vigor                         = Spell(14983),
    -- Artifact
    BagofTricks                   = Spell(192657),
    Kingsbane                     = Spell(192759),
    UrgetoKill                    = Spell(192384),
    -- Defensive
    CrimsonVial                   = Spell(185311),
    Feint                         = Spell(1966),
    -- Utility
    Kick                          = Spell(1766),
    Sprint                        = Spell(2983),
    -- Poisons
    AgonizingPoison               = Spell(200802),
    AgonizingPoisonDebuff         = Spell(200803),
    DeadlyPoison                  = Spell(2823),
    DeadlyPoisonDebuff            = Spell(2818),
    LeechingPoison                = Spell(108211),
    -- Legendaries
    DreadlordsDeceit              = Spell(228224),
    -- Tier
    MutilatedFlesh                = Spell(211672),
    -- Misc
    PoolEnergy                    = Spell(9999000001)
  };
  local S = Spell.Rogue.Assassination;
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Assassination = {
    -- Legendaries
  };
  local I = Item.Rogue.Assassination;
-- Rotation Var
  local ShouldReturn, ShouldReturn2; -- Used to get the return string
   local CountA, CountB; -- Used for potential Rupture units
  local BestUnit, BestUnitTTD; -- Used for cycling
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Rogue.Commons,
    Assassination = AR.GUISettings.APL.Rogue.Assassination
  };

-- APL Action Lists (and Variables)
-- # Builders
local function Build ()
   if S.Hemorrhage:IsCastable() then
      -- actions.build=hemorrhage,if=refreshable
      if Target:IsInRange(5) and Target:DebuffRefreshable(S.Hemorrhage) then
        if AR.Cast(S.Hemorrhage) then return "Cast"; end
      end
      -- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<=3
      if AR.AoEON() then
        BestUnit, BestUnitTTD = nil, 0;
      for Key, Value in pairs(Cache.Enemies[5]) do
        if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and
              Value:TimeToDie() > BestUnitTTD and
              Value:DebuffRefreshable(S.Hemorrhage)
              then
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        AR.Nameplate.AddIcon(BestUnit, S.Hemorrhage);
      end
      end
   end
   -- actions.build+=/fan_of_knives,if=spell_targets>=3|buff.the_dreadlords_deceit.stack>=29
   if AR.AoEON() and
      S.FanofKnives:IsCastable() and
      (Cache.EnemiesCount[10] >= 3 or (Target:IsInRange(5) and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
      if AR.Cast(S.Hemorrhage) then return "Cast"; end
   end
   -- actions.build+=/mutilate,cycle_targets=1,if=(!talent.agonizing_poison.enabled&dot.deadly_poison_dot.refreshable)|(talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<debuff.agonizing_poison.duration*0.3)|(set_bonus.tier19_2pc=1&dot.mutilated_flesh.refreshable)
   -- TODO : Check if MutilatedFlesh got pandemic or not
   if S.Mutilate:IsCastable() then
      if Target:IsInRange(5) and
        (not S.AgonizingPoison:IsAvailable() and Target:DebuffRefreshable(DeadlyPoisonDebuff, 4)) or
        (S.AgonizingPoison:IsAvailable() and Target:DebuffRefreshable(AgonizingPoisonDebuff, 4)) or
        (AC.Tier19_2Pc and Target:DebuffRefreshable(S.MutilatedFlesh, 0)) then
        if AR.Cast(S.Mutilate) then return "Cast"; end
      end
      if AR.AoEON() then
        BestUnit, BestUnitTTD = nil, 0;
      for Key, Value in pairs(Cache.Enemies[5]) do
        if not Value:IsFacingBlacklisted() and
              Value:TimeToDie() < 7777 and Value:TimeToDie() > BestUnitTTD and
              (not S.AgonizingPoison:IsAvailable() and Value:DebuffRefreshable(DeadlyPoisonDebuff, 4)) or
              (S.AgonizingPoison:IsAvailable() and Value:DebuffRefreshable(AgonizingPoisonDebuff, 4)) or
              (AC.Tier19_2Pc and Value:DebuffRefreshable(S.MutilatedFlesh, 0)) then
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        AR.Nameplate.AddIcon(BestUnit, S.Mutilate);
      end
      end
   end
   -- actions.build+=/mutilate
   if S.Mutilate:IsCastable() and Target:IsInRange(5) then
      if AR.Cast(S.Mutilate) then return "Cast"; end
   end
  return false;
end
-- # Cooldowns
local function CDs ()
  if Target:IsInRange(5) then
      -- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|debuff.vendetta.up
    if Target:Debuff(S.Vendetta) then
      -- actions.cds+=/blood_fury,if=debuff.vendetta.up
      if S.BloodFury:IsCastable() then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.BloodFury) then return "Cast"; end
      end
      -- actions.cds+=/berserking,if=debuff.vendetta.up
      if S.Berserking:IsCastable() then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Berserking) then return "Cast"; end
      end
      -- actions.cds+=/arcane_torrent,if=debuff.vendetta.up&energy.deficit>50
      if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficit() > 50 then
        if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
      end
    end
      -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|(raid_event.adds.in>40&combo_points.deficit>=4+talent.deeper_strategem.enabled+talent.anticipation.enabled)
    --[[Normal MfD
    if not S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= 4+(S.DeeperStratagem:IsAvailable() and 1 or 0)+(S.Anticipation:IsAvailable() and 1 or 0) then
      if AR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast"; end
    end]]
      -- actions.cds+=/vendetta,if=talent.exsanguinate.enabled&cooldown.exsanguinate.remains<5&dot.rupture.ticking
      -- actions.cds+=/vendetta,if=!talent.exsanguinate.enabled&(!artifact.urge_to_kill.enabled|energy.deficit>=70)
      -- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&((talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10))|(!talent.exsanguinate.enabled&dot.rupture.refreshable))
      -- actions.cds+=/vanish,if=talent.subterfuge.enabled&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
      -- actions.cds+=/vanish,if=talent.shadow_focus.enabled&energy.time_to_max>=2&combo_points.deficit>=4
      -- actions.cds+=/exsanguinate,if=prev_gcd.rupture&dot.rupture.remains>4+4*cp_max_spend
  end
  return false;
end
-- # Finishers
local function Finish ()
  -- actions.finish=death_from_above,if=combo_points>=cp_max_spend
  if S.DeathFromAbove:IsCastable() and Target:IsInRange(15) and Player:ComboPoints() >= Player:ComboPointsMax() then
    if AR.Cast(S.DeathFromAbove) then return "Cast"; end
  end
   -- actions.finish+=/envenom,if=combo_points>=cp_max_spend-talent.master_poisoner.enabled|(talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<2)
  if S.Envenom:IsCastable() and Target:IsInRange(5) and
      (Player:ComboPoints() >= Player:ComboPointsMax()-(S.MasterPoisoner:IsAvailable() and 1 or 0)) or
      (S.ElaboratePlanning:IsAvailable() and
        Player:ComboPoints() >= 3 + (S.Exsanguinate:IsAvailable() and 0 or 1) and
        Player:BuffRemains(S.ElaboratePlanningBuff) <= 2
      ) then
      if AR.Cast(S.Envenom) then return "Cast"; end
   end
   return false;
end
-- # Maintain
local function Maintain ()
   if S.Rupture:IsCastable() then
      -- actions.maintain=rupture,if=(talent.nightstalker.enabled&stealthed.rogue)|(talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled))))
      if Target:IsInRange(5) and
        (
           (S.Nightstalker:IsAvailable() and Player:IsStealthed(true, false)) or
           (S.Exsanguinate:IsAvailable() and 
              (
                (Player:ComboPoints() >= Player:ComboPointsMax() and S.Exsanguinate:Cooldown() < 1) or
                (
                   not Target:Debuff(S.Rupture) and
                   (AC.CombatTime() > 10 or (Player:ComboPoints() >= 2+(S.UrgetoKill:ArtifactEnabled() and 1 or 0)))
                )
              )
           )
        ) then
        if AR.Cast(S.Rupture) then return "Cast"; end
      end
      -- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=cp_max_spend-talent.exsanguinate.enabled&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
      if Player:ComboPoints() >= Player:ComboPointsMax()-(S.Exsanguinate:IsAvailable() and 1 or 0) then
        if Target:IsInRange(5) and
           Target:DebuffRefreshable(S.Rupture, (4+Player:ComboPoints()*4)*0.3) and
           (not AC.Exsanguinated(Target, "Rupture") or Target:DebuffRemains(S.Rupture) <= 1.5) and
           Target:TimeToDie()-Target:DebuffRemains(S.Rupture) > 4 then
           if AR.Cast(S.Rupture) then return "Cast"; end
        end
        if AR.AoEON() then
           BestUnit, BestUnitTTD = nil, 4;
           for Key, Value in pairs(Cache.Enemies[5]) do
              if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and
                Value:TimeToDie()-Value:DebuffRemains(S.Rupture) > BestUnitTTD and
                Value:DebuffRefreshable(S.Rupture, (4+Player:ComboPoints()*4)*0.3) and
                (not AC.Exsanguinated(Value, "Rupture") or Value:DebuffRemains(S.Rupture) <= 1.5) then
                BestUnit, BestUnitTTD = Value, Value:TimeToDie();
              end
           end
           if BestUnit then
              AR.Nameplate.AddIcon(BestUnit, S.Rupture);
           end
        end
      end
   end
   -- actions.maintain+=/kingsbane,if=(talent.exsanguinate.enabled&dot.rupture.exsanguinated)|(!talent.exsanguinate.enabled&(debuff.vendetta.up|cooldown.vendetta.remains>10))
   if S.Kingsbane:IsCastable() and Target:IsInRange(5) and
      (S.Exsanguinate:IsAvailable() and AC.Exsanguinated(Target, "Rupture")) or
      (not S.Exsanguinate:IsAvailable() and (Target:Debuff(S.Vendetta) or Vendetta:Cooldown() > 10)) then
      if AR.Cast(S.Kingsbane) then return "Cast"; end
   end
   -- actions.maintain+=/garrote,cycle_targets=1,if=refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
   if S.Garrote:IsCastable() then
      if Target:IsInRange(5) and Target:DebuffRefreshable(S.Garrote, 5.4) and
        (not AC.Exsanguinated(Target, "Garrote") or Target:DebuffRemains(S.Garrote) <= 1.5) and
        Target:TimeToDie()-Target:DebuffRemains(S.Garrote) > 4 then
        -- actions.maintain+=/pool_resource,for_next=1
        if Player:Energy() < 45 then
           if AR.Cast(S.PoolEnergy) then return "Pool for Garrote (ST)"; end
        end
        if AR.Cast(S.Garrote) then return "Cast"; end
      end
      if AR.AoEON() then
        BestUnit, BestUnitTTD = nil, 4;
        for Key, Value in pairs(Cache.Enemies[5]) do
           if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and
              Value:TimeToDie()-Value:DebuffRemains(S.Garrote) > BestUnitTTD and
              Value:DebuffRefreshable(S.Garrote, 5.4) and
              (not AC.Exsanguinated(Value, "Garrote") or Value:DebuffRemains(S.Garrote) <= 1.5) then
              BestUnit, BestUnitTTD = Value, Value:TimeToDie();
           end
        end
        if BestUnit then
           -- actions.maintain+=/pool_resource,for_next=1
           if Player:Energy() < 45 then
              if AR.Cast(S.PoolEnergy) then return "Pool for Garrote (Cycle)"; end
           end
           AR.Nameplate.AddIcon(BestUnit, S.Garrote);
        end
      end
   end
end
local SappedSoulSpells = {
  {S.Kick, "Cast Kick (Sappel Soul)", function () return Target:IsInRange(5); end},
  {S.Feint, "Cast Feint (Sappel Soul)", function () return true; end},
  {S.CrimsonVial, "Cast Crimson Vial (Sappel Soul)", function () return true; end}
};
local function MythicDungeon ()
  -- Sapped Soul
  if AC.MythicDungeon() == "Sapped Soul" then
    for i = 1, #SappedSoulSpells do
      if SappedSoulSpells[i][1]:IsCastable() and SappedSoulSpells[i][3]() then
        AC.ChangePulseTimer(1);
        AR.Cast(SappedSoulSpells[i][1]);
        return SappedSoulSpells[i][2];
      end
    end
  end
  return false;
end
local function TrainingScenario ()
  if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*Player:ComboPoints() then
    -- Kidney Shot
    if Target:IsInRange(5) and S.KidneyShot:IsCastable() and Player:ComboPoints() > 0 then
      if AR.Cast(S.KidneyShot) then return "Cast Kidney Shot (Unstable Explosion)"; end
    end
  end
  return false;
end

-- APL Main
local function APL ()
  -- Spell ID Changes check
  S.Stealth = S.Subterfuge:IsAvailable() and Spell(115191) or Spell(1784); -- w/ or w/o Subterfuge Talent
  -- Unit Update
  AC.GetEnemies(10); -- Fan of Knives
  AC.GetEnemies(5); -- Melee
  --- Defensives
    -- Crimson Vial
    ShouldReturn = AR.Commons.Rogue.CrimsonVial (S.CrimsonVial);
    if ShouldReturn then return ShouldReturn; end
    -- Feint
    ShouldReturn = AR.Commons.Rogue.Feint (S.Feint);
    if ShouldReturn then return ShouldReturn; end
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Stealth
      ShouldReturn = AR.Commons.Rogue.Stealth (S.Stealth);
      if ShouldReturn then return ShouldReturn; end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if AR.Commons.TargetIsValid() and Target:IsInRange(5) then
        if Player:ComboPoints() >= 5 then
          if S.Rupture:IsCastable() and not Target:Debuff(S.Rupture) then
            if AR.Cast(S.Rupture) then return "Cast"; end
          elseif S.Envenom:IsCastable() then
            if AR.Cast(S.Envenom) then return "Cast"; end
          end
        elseif S.Garrote:IsCastable() then
          if AR.Cast(S.Garrote) then return "Cast"; end
        elseif S.Mutilate:IsCastable() then
          if AR.Cast(S.Mutilate) then return "Cast"; end
        end
      end
      return;
    end
  -- In Combat
    -- MfD Sniping
    AR.Commons.Rogue.MfDSniping(S.MarkedforDeath);
    if AR.Commons.TargetIsValid() then
      -- Mythic Dungeon
      ShouldReturn = MythicDungeon();
      if ShouldReturn then return ShouldReturn; end
      -- Training Scenario
      ShouldReturn = TrainingScenario();
      if ShouldReturn then return ShouldReturn; end
      -- Interrupts
      AR.Commons.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, {
        {S.Blind, "Cast Blind (Interrupt)", function () return true; end},
        {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return Player:ComboPoints() > 0; end}
      });
      -- actions+=/call_action_list,name=cds
      if AR.CDsON() then
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      end
        -- actions+=/call_action_list,name=maintain
        -- # The 'active_dot.rupture>=spell_targets.rupture' means that we don't want to envenom as long as we can multi-rupture (i.e. units that don't have rupture yet).
        CountA, CountB = 0, 0;
        if AR.AoEON() then
           for Key, Value in pairs(Cache.Enemies[5]) do
              
              if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and
                not Value:DebuffRefreshable(Rupture, (4+Player:ComboPoints()*4)*0.3) and
                Value:TimeToDie()-Value:DebuffRemains(Rupture) > 4 then
                CountA = CountA + 1;
              end

              if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and
                Value:TimeToDie()-Value:DebuffRemains(Rupture) > 4 then
                CountB = CountB + 1;
              end
           end
        end
        -- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)&(!dot.rupture.refreshable|(dot.rupture.exsanguinated&dot.rupture.remains>=3.5)|target.time_to_die-dot.rupture.remains<=4)&active_dot.rupture>=spell_targets.rupture
        if true then
        ShouldReturn = Finish();
        if ShouldReturn then return ShouldReturn; end
      end
        
        -- actions+=/call_action_list,name=build,if=(combo_points.deficit>0|energy.time_to_max<1)
        if true then
        ShouldReturn = Build();
        if ShouldReturn then return ShouldReturn; end
      end
      -- Shuriken Toss Out of Range
      if not Target:IsInRange(10) and Target:IsInRange(20) and S.ShurikenToss:IsCastable() and not Player:IsStealthed(true, true) and Player:EnergyDeficit() < 20 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
        if AR.Cast(S.ShurikenToss) then return "Cast Shuriken Toss"; end
      end
      if S.Mutilate:IsCastable() then -- Trick to take in consideration the Recovery Setting
        if AR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
      end
    end
end

AR.SetAPL(259, APL);

-- Last Update: 01/19/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,name=flask_of_the_seventh_demon
-- actions.precombat+=/augmentation,name=defiled
-- actions.precombat+=/food,name=seedbattered_fish_plate
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/apply_poison
-- actions.precombat+=/stealth
-- actions.precombat+=/potion,name=old_war
-- actions.precombat+=/marked_for_death,if=raid_event.adds.in>40

-- # Executed every time the actor is available.
-- actions=call_action_list,name=cds
-- actions+=/call_action_list,name=maintain
-- # The 'active_dot.rupture>=spell_targets.rupture' means that we don't want to envenom as long as we can multi-rupture (i.e. units that don't have rupture yet).
-- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)&(!dot.rupture.refreshable|(dot.rupture.exsanguinated&dot.rupture.remains>=3.5)|target.time_to_die-dot.rupture.remains<=4)&active_dot.rupture>=spell_targets.rupture
-- actions+=/call_action_list,name=build,if=(combo_points.deficit>0|energy.time_to_max<1)

-- # Builders
-- actions.build=hemorrhage,if=refreshable
-- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<=3
-- actions.build+=/fan_of_knives,if=spell_targets>=3|buff.the_dreadlords_deceit.stack>=29
-- actions.build+=/mutilate,cycle_targets=1,if=(!talent.agonizing_poison.enabled&dot.deadly_poison_dot.refreshable)|(talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<debuff.agonizing_poison.duration*0.3)|(set_bonus.tier19_2pc=1&dot.mutilated_flesh.refreshable)
-- actions.build+=/mutilate

-- # Cooldowns
-- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|debuff.vendetta.up
-- actions.cds+=/blood_fury,if=debuff.vendetta.up
-- actions.cds+=/berserking,if=debuff.vendetta.up
-- actions.cds+=/arcane_torrent,if=debuff.vendetta.up&energy.deficit>50
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|combo_points.deficit>=5
-- actions.cds+=/vendetta,if=talent.exsanguinate.enabled&cooldown.exsanguinate.remains<5&dot.rupture.ticking
-- actions.cds+=/vendetta,if=talent.exsanguinate.enabled&(artifact.master_assassin.rank>=4-equipped.convergence_of_fates|equipped.duskwalkers_footpads)&energy.deficit>=75&!(artifact.master_assassin.rank=5-equipped.convergence_of_fates&equipped.duskwalkers_footpads)
-- actions.cds+=/vendetta,if=!talent.exsanguinate.enabled&energy.deficit>=88-!talent.venom_rush.enabled*10
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&((talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10))|(!talent.exsanguinate.enabled&dot.rupture.refreshable))
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
-- actions.cds+=/vanish,if=talent.shadow_focus.enabled&energy.time_to_max>=2&combo_points.deficit>=4
-- actions.cds+=/exsanguinate,if=prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend

-- # Finishers
-- actions.finish=death_from_above,if=combo_points>=cp_max_spend
-- actions.finish+=/envenom,if=combo_points>=4|(talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<0.1)

-- # Maintain
-- actions.maintain=rupture,if=talent.nightstalker.enabled&stealthed.rogue
-- actions.maintain+=/rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
-- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&!ticking
-- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=cp_max_spend-talent.exsanguinate.enabled&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
-- actions.maintain+=/kingsbane,if=(talent.exsanguinate.enabled&dot.rupture.exsanguinated)|(!talent.exsanguinate.enabled&buff.envenom.up&(debuff.vendetta.up|cooldown.vendetta.remains>10))
-- actions.maintain+=/pool_resource,for_next=1
-- actions.maintain+=/garrote,cycle_targets=1,if=refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
