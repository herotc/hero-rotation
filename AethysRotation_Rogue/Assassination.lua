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
    PoolEnergy                    = Spell(9999000010)
  };
  local S = Spell.Rogue.Assassination;
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Assassination = {
    -- Legendaries
    InsigniaofRavenholdt          = Item(137049)    -- 11 & 12
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
    -- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+talent.agonizing_poison.enabled+(talent.agonizing_poison.enabled&equipped.insignia_of_ravenholdt)
    if AR.AoEON() and Cache.EnemiesCount[10] < 2+(S.AgonizingPoison:IsAvailable() and 1 or 0)+(S.AgonizingPoison:IsAvailable() and (I.InsigniaofRavenholdt:IsEquipped(11) or I.InsigniaofRavenholdt:IsEquipped(12)) and 1 or 0) then
      BestUnit, BestUnitTTD = nil, 0;
      for Key, Value in pairs(Cache.Enemies[5]) do
        if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and Value:TimeToDie() > BestUnitTTD and Value:DebuffRefreshable(S.Hemorrhage) and Value:Debuff(S.Rupture) then
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Hemorrhage);
      end
    end
  end
  -- actions.build+=/fan_of_knives,if=spell_targets>=2+talent.agonizing_poison.enabled+(talent.agonizing_poison.enabled&equipped.insignia_of_ravenholdt)|buff.the_dreadlords_deceit.stack>=29
  if S.FanofKnives:IsCastable() and (Cache.EnemiesCount[10] >= 2+(S.AgonizingPoison:IsAvailable() and 1 or 0)+(S.AgonizingPoison:IsAvailable() and (I.InsigniaofRavenholdt:IsEquipped(11) or I.InsigniaofRavenholdt:IsEquipped(12)) and 1 or 0) or (AR.AoEON() and Target:IsInRange(5) and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
    if AR.Cast(S.FanofKnives) then return "Cast"; end
  end
  if S.Mutilate:IsCastable() then
    -- actions.build+=/mutilate,cycle_targets=1,if=(!talent.agonizing_poison.enabled&dot.deadly_poison_dot.refreshable)|(talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<debuff.agonizing_poison.duration*0.3)
    if Target:IsInRange(5) and ((not S.AgonizingPoison:IsAvailable() and Target:DebuffRefreshable(S.DeadlyPoisonDebuff, 4)) or (S.AgonizingPoison:IsAvailable() and Target:DebuffRefreshable(S.AgonizingPoisonDebuff, 4))) then
      if AR.Cast(S.Mutilate) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD = nil, 0;
      for Key, Value in pairs(Cache.Enemies[5]) do
        if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and Value:TimeToDie() > BestUnitTTD
          and ((not S.AgonizingPoison:IsAvailable() and Value:DebuffRefreshable(S.DeadlyPoisonDebuff, 4))
            or (S.AgonizingPoison:IsAvailable() and Value:DebuffRefreshable(S.AgonizingPoisonDebuff, 4))) then
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Mutilate);
      end
    end
    -- actions.build+=/mutilate,if=cooldown.vendetta.remains<7|debuff.vendetta.up|debuff.kingsbane.up|energy.deficit<=22|target.time_to_die<6
    if Target:IsInRange(5) and ((AR.CDsON() and S.Vendetta:Cooldown() < 7) or Target:Debuff(S.Vendetta) or Target:Debuff(S.Kingsbane) or Player:EnergyDeficit() <= 22 or Target:TimeToDie() < 6) then
      if AR.Cast(S.Mutilate) then return "Cast"; end
    end
  end
  return false;
end
-- # Cooldowns
local function CDs ()
  if Target:IsInRange(5) then
    -- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|debuff.vendetta.up&cooldown.vanish.remains<5
    if Target:Debuff(S.Vendetta) then
      -- actions.cds+=/blood_fury,if=debuff.vendetta.up
      if S.BloodFury:IsCastable() then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.BloodFury) then return "Cast"; end
      end
      -- actions.cds+=/berserking,if=debuff.vendetta.up
      if S.Berserking:IsCastable() then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Berserking) then return "Cast"; end
      end
      -- actions.cds+=/arcane_torrent,if=debuff.vendetta.up&energy.deficit>30
      if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficit() > 30 then
        if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
      end
    end
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
    if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= AR.Commons.Rogue.CPMaxSpend() then
      AR.CastSuggested(S.MarkedforDeath);
    end
    -- actions.cds+=/vendetta,if=talent.exsanguinate.enabled&(!artifact.urge_to_kill.enabled|energy.deficit>=75+talent.vigor.enabled*50)
    if S.Vendetta:IsCastable() and S.Exsanguinate:IsAvailable() and (not S.UrgetoKill:ArtifactEnabled() or Player:EnergyDeficit() >= 75+(S.Vigor:IsAvailable() and 50 or 0)) then
      if AR.Cast(S.Vendetta, Settings.Assassination.OffGCDasOffGCD.Vendetta) then return "Cast"; end
    end
    -- actions.cds+=/vendetta,if=!talent.exsanguinate.enabled&(!artifact.urge_to_kill.enabled|(!talent.vigor.enabled&energy.deficit>=85)|(talent.vigor.enabled&energy.deficit>=125))
    if S.Vendetta:IsCastable() and not S.Exsanguinate:IsAvailable() and (not S.UrgetoKill:ArtifactEnabled() or Player:EnergyDeficit() >= 85+(S.Vigor:IsAvailable() and 40 or 0)) then
      if AR.Cast(S.Vendetta, Settings.Assassination.OffGCDasOffGCD.Vendetta) then return "Cast"; end
    end
    if S.Vanish:IsCastable() and not Player:IsTanking(Target) then
      -- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&((talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10))|(!talent.exsanguinate.enabled&dot.rupture.refreshable))
      if S.Nightstalker:IsAvailable() and Player:ComboPoints() >= AR.Commons.Rogue.CPMaxSpend() and ((S.Exsanguinate:IsAvailable() and S.Exsanguinate:Cooldown() < 1 and (Target:Debuff(S.Rupture) or AC.CombatTime() > 10)) or (not S.Exsanguinate:IsAvailable() and Target:DebuffRefreshable(S.Rupture, (4+Player:ComboPoints()*4)*0.3))) then
        if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
      end
      -- actions.cds+=/vanish,if=talent.subterfuge.enabled&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
      if S.Subterfuge:IsAvailable() and Target:DebuffRefreshable(S.Garrote, 5.4) and ((Cache.EnemiesCount[10] <= 3 and Player:ComboPointsDeficit() >= 1+Cache.EnemiesCount[10]) or (Cache.EnemiesCount[10] >= 4 and Player:ComboPointDeficit())) then
        if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
      end
      -- actions.cds+=/vanish,if=talent.shadow_focus.enabled&energy.time_to_max>=2&combo_points.deficit>=4
      if S.ShadowFocus:IsAvailable() and Player:EnergyTimeToMax() >= 2 and Player:ComboPoints() >= 4 then
        if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
      end
    end
    -- actions.cds+=/exsanguinate,if=prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend
    if S.Exsanguinate:IsCastable() and S.Rupture:TimeSinceLastDisplay() < 2 and Target:DebuffRemains(S.Rupture) > 4+4*AR.Commons.Rogue.CPMaxSpend() then
      if AR.Cast(S.Exsanguinate) then return "Cast"; end
    end
  end
  return false;
end
-- # Finishers
local function Finish ()
  -- actions.finish=death_from_above,if=combo_points>=cp_max_spend
  if S.DeathFromAbove:IsCastable() and Target:IsInRange(15) and Player:ComboPoints() >= AR.Commons.Rogue.CPMaxSpend() then
    if AR.Cast(S.DeathFromAbove) then return "Cast"; end
  end
  -- actions.finish+=/envenom,if=combo_points>=4|(talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<0.3)
  if S.Envenom:IsCastable() and Target:IsInRange(5) and (Player:ComboPoints() >= 4 or (S.ElaboratePlanning:IsAvailable() and Player:ComboPoints() >= 3+(S.Exsanguinate:IsAvailable() and 0 or 1) and Player:BuffRemains(S.ElaboratePlanningBuff) <= 0.3)) then
      if AR.Cast(S.Envenom) then return "Cast"; end
   end
   return false;
end
-- # Maintain
local function Maintain ()
  if S.Rupture:IsCastable() and Player:ComboPoints() >= 1 then
    if Target:IsInRange(5) then
      -- actions.maintain=rupture,if=talent.nightstalker.enabled&stealthed.rogue
      if S.Nightstalker:IsAvailable() and Player:IsStealthed(true, false) then
        if AR.Cast(S.Rupture) then return "Cast"; end
      end
      -- actions.maintain+=/rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
      if AR.CDsON() and S.Exsanguinate:IsAvailable() and ((Player:ComboPoints() >= AR.Commons.Rogue.CPMaxSpend() and S.Exsanguinate:Cooldown() < 1) or (not Target:Debuff(S.Rupture) and (AC.CombatTime() > 10 or (Player:ComboPoints() >= 2+(S.UrgetoKill:ArtifactEnabled() and 1 or 0))))) then
        if AR.Cast(S.Rupture) then return "Cast"; end
      end
      -- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&!ticking
      if not S.Exsanguinate:IsAvailable() and not Target:Debuff(S.Rupture) then
        if AR.Cast(S.Rupture) then return "Cast"; end
      end
    end
    -- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=cp_max_spend-talent.exsanguinate.enabled&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
    if Player:ComboPoints() >= AR.Commons.Rogue.CPMaxSpend()-(S.Exsanguinate:IsAvailable() and 1 or 0) then
      if Target:IsInRange(5) and Target:DebuffRefreshable(S.Rupture, (4+Player:ComboPoints()*4)*0.3)
          and (not AC.Exsanguinated(Target, "Rupture") or Target:DebuffRemains(S.Rupture) <= 1.5)
          and Target:TimeToDie()-Target:DebuffRemains(S.Rupture) > 4 then
         if AR.Cast(S.Rupture) then return "Cast"; end
      end
      if AR.AoEON() then
         BestUnit, BestUnitTTD = nil, 4;
         for Key, Value in pairs(Cache.Enemies[5]) do
            if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and Value:TimeToDie()-Value:DebuffRemains(S.Rupture) > BestUnitTTD
                and Value:DebuffRefreshable(S.Rupture, (4+Player:ComboPoints()*4)*0.3) and (not AC.Exsanguinated(Value, "Rupture") or Value:DebuffRemains(S.Rupture) <= 1.5) then
              BestUnit, BestUnitTTD = Value, Value:TimeToDie();
            end
         end
         if BestUnit then
            AR.CastLeftNameplate(BestUnit, S.Rupture);
         end
      end
    end
  end
  -- actions.maintain+=/kingsbane,if=(talent.exsanguinate.enabled&dot.rupture.exsanguinated)|(!talent.exsanguinate.enabled&buff.envenom.up&(debuff.vendetta.up|cooldown.vendetta.remains>10))
  if S.Kingsbane:IsCastable() and Target:IsInRange(5) and ((S.Exsanguinate:IsAvailable() and AC.Exsanguinated(Target, "Rupture"))
      or (not S.Exsanguinate:IsAvailable() and Player:Buff(S.EnvenomBuff) and (Target:Debuff(S.Vendetta) or S.Vendetta:Cooldown() > 10))) then
    if AR.Cast(S.Kingsbane) then return "Cast"; end
  end
  -- actions.maintain+=/garrote,cycle_targets=1,if=combo_points.deficit>=1&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
  if S.Garrote:IsCastable() and Player:ComboPointsDeficit() >= 1 then
    if Target:IsInRange(5) and Target:DebuffRefreshable(S.Garrote, 5.4) and (not AC.Exsanguinated(Target, "Garrote") or Target:DebuffRemains(S.Garrote) <= 1.5)
        and Target:TimeToDie()-Target:DebuffRemains(S.Garrote) > 4 then
      -- actions.maintain+=/pool_resource,for_next=1
      if Player:Energy() < 45 then
        if AR.Cast(S.PoolEnergy) then return "Pool for Garrote (ST)"; end
      end
      if AR.Cast(S.Garrote) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD = nil, 4;
      for Key, Value in pairs(Cache.Enemies[5]) do
         if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and Value:TimeToDie()-Value:DebuffRemains(S.Garrote) > BestUnitTTD
             and Value:DebuffRefreshable(S.Garrote, 5.4) and (not AC.Exsanguinated(Value, "Garrote") or Value:DebuffRemains(S.Garrote) <= 1.5) then
            BestUnit, BestUnitTTD = Value, Value:TimeToDie();
         end
      end
      if BestUnit then
        -- actions.maintain+=/pool_resource,for_next=1
        if Player:Energy() < 45 then
          if AR.Cast(S.PoolEnergy) then return "Pool for Garrote (Cycle)"; end
        end
        AR.CastLeftNameplate(BestUnit, S.Garrote);
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
        AR.ChangePulseTimer(1);
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
  AC.GetEnemies(10);    -- Fan of Knives
  AC.GetEnemies(5);     -- Melee
  AR.Commons.AoEToggleEnemiesUpdate();
  --- Defensives
    -- Crimson Vial
    ShouldReturn = AR.Commons.Rogue.CrimsonVial(S.CrimsonVial);
    if ShouldReturn then return ShouldReturn; end
    -- Feint
    ShouldReturn = AR.Commons.Rogue.Feint(S.Feint);
    if ShouldReturn then return ShouldReturn; end
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Stealth
      ShouldReturn = AR.Commons.Rogue.Stealth(S.Stealth);
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
      -- actions=call_action_list,name=cds
      if AR.CDsON() then
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=maintain
      ShouldReturn = Maintain();
      if ShouldReturn then return ShouldReturn; end
      -- # The 'active_dot.rupture>=spell_targets.rupture' means that we don't want to envenom as long as we can multi-rupture (i.e. units that don't have rupture yet).
      -- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)&(!dot.rupture.refreshable|(dot.rupture.exsanguinated&dot.rupture.remains>=3.5)|target.time_to_die-dot.rupture.remains<=4)&active_dot.rupture>=spell_targets.rupture
      CountA, CountB = 1, 0;
      if AR.AoEON() then
        for Key, Value in pairs(Cache.Enemies[5]) do
          if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and Value:TimeToDie()-Value:DebuffRemains(S.Rupture) > 4 then
            if not Value:DebuffRefreshable(S.Rupture, (4+Player:ComboPoints()*4)*0.3) then
              CountA = CountA + 1;
            else
              CountB = CountB + 1;
            end
          end
        end
      end
      if (not AR.CDsON() or not S.Exsanguinate:IsAvailable() or S.Exsanguinate:Cooldown() > 2) and (not Target:DebuffRefreshable(S.Rupture, (4+Player:ComboPoints()*4)*0.3) or (AC.Exsanguinated(Target, "Rupture") and Target:DebuffRemains(S.Rupture) >= 3.5) or Target:TimeToDie()-Target:DebuffRemains(S.Rupture) <= 4) and CountA >= Cache.EnemiesCount[5]-CountB then
        ShouldReturn = Finish();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=build,if=(combo_points.deficit>0|energy.time_to_max<1)
      if Player:ComboPointsDeficit() > 0 or Player:EnergyTimeToMax() < 1 then
        ShouldReturn = Build();
        if ShouldReturn then return ShouldReturn; end
      end
      -- Poisoned Knife Out of Range
      if not Target:IsInRange(10) and Target:IsInRange(20) and S.PoisonedKnife:IsCastable() and not Player:IsStealthed(true, true) and Player:EnergyDeficit() < 20 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
        if AR.Cast(S.PoisonedKnife) then return "Cast Shuriken Toss"; end
      end
      -- Trick to take in consideration the Recovery Setting
      if S.Mutilate:IsCastable() and Target:IsInRange(5) then
        if AR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
      end
    end
end

AR.SetAPL(259, APL);

-- Last Update: 02/27/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,name=flask_of_the_seventh_demon
-- actions.precombat+=/augmentation,name=defiled
-- actions.precombat+=/food,name=seedbattered_fish_plate,if=talent.exsanguinate.enabled
-- actions.precombat+=/food,name=nightborne_delicacy_platter,if=!talent.exsanguinate.enabled
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
-- actions+=/call_action_list,name=build,if=combo_points.deficit>0|energy.time_to_max<1

-- # Builders
-- actions.build=hemorrhage,if=refreshable
-- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+talent.agonizing_poison.enabled+(talent.agonizing_poison.enabled&equipped.insignia_of_ravenholdt)
-- actions.build+=/fan_of_knives,if=spell_targets>=2+talent.agonizing_poison.enabled+(talent.agonizing_poison.enabled&equipped.insignia_of_ravenholdt)|buff.the_dreadlords_deceit.stack>=29
-- actions.build+=/mutilate,cycle_targets=1,if=(!talent.agonizing_poison.enabled&dot.deadly_poison_dot.refreshable)|(talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<debuff.agonizing_poison.duration*0.3)
-- actions.build+=/mutilate,if=cooldown.vendetta.remains<7|debuff.vendetta.up|debuff.kingsbane.up|energy.deficit<=22|target.time_to_die<6

-- # Cooldowns
-- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|debuff.vendetta.up&cooldown.vanish.remains<5
-- actions.cds+=/blood_fury,if=debuff.vendetta.up
-- actions.cds+=/berserking,if=debuff.vendetta.up
-- actions.cds+=/arcane_torrent,if=debuff.vendetta.up&energy.deficit>30
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
-- actions.cds+=/vendetta,if=talent.exsanguinate.enabled&(!artifact.urge_to_kill.enabled|energy.deficit>=75+talent.vigor.enabled*50)
-- actions.cds+=/vendetta,if=!talent.exsanguinate.enabled&(!artifact.urge_to_kill.enabled|energy.deficit>=85+talent.vigor.enabled*40)
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&((talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10))|(!talent.exsanguinate.enabled&dot.rupture.refreshable))
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
-- actions.cds+=/vanish,if=talent.shadow_focus.enabled&energy.time_to_max>=2&combo_points.deficit>=4
-- actions.cds+=/exsanguinate,if=prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend

-- # Finishers
-- actions.finish=death_from_above,if=combo_points>=cp_max_spend
-- actions.finish+=/envenom,if=combo_points>=4|(talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<0.3)

-- # Maintain
-- actions.maintain=rupture,if=talent.nightstalker.enabled&stealthed.rogue
-- actions.maintain+=/rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
-- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&!ticking
-- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=cp_max_spend-talent.exsanguinate.enabled&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
-- actions.maintain+=/kingsbane,if=(talent.exsanguinate.enabled&dot.rupture.exsanguinated)|(!talent.exsanguinate.enabled&buff.envenom.up&(debuff.vendetta.up|cooldown.vendetta.remains>10))
-- actions.maintain+=/pool_resource,for_next=1
-- actions.maintain+=/garrote,cycle_targets=1,if=combo_points.deficit>=1&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
