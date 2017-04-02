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
local pairs = pairs;


--- APL Local Vars
-- Commons
  local Rogue = AR.Commons.Rogue;
-- Spells
  if not Spell.Rogue then Spell.Rogue = {}; end
  Spell.Rogue.Assassination = {
    -- Racials
    ArcaneTorrent         = Spell(25046),
    Berserking            = Spell(26297),
    BloodFury             = Spell(20572),
    GiftoftheNaaru        = Spell(59547),
    -- Abilities
    Envenom               = Spell(32645),
    FanofKnives           = Spell(51723),
    Garrote               = Spell(703),
    KidneyShot            = Spell(408),
    Mutilate              = Spell(1329),
    PoisonedKnife         = Spell(185565),
    Rupture               = Spell(1943),
    Stealth               = Spell(1784),
    Vanish                = Spell(1856),
    Vendetta              = Spell(79140),
    -- Talents
    Alacrity              = Spell(193539),
    AlacrityBuff          = Spell(193538),
    Anticipation          = Spell(114015),
    DeathfromAbove        = Spell(152150),
    DeeperStratagem       = Spell(193531),
    ElaboratePlanning     = Spell(193640),
    ElaboratePlanningBuff = Spell(193641),
    Exsanguinate          = Spell(200806),
    Hemorrhage            = Spell(16511),
    MarkedforDeath        = Spell(137619),
    MasterPoisoner        = Spell(196864),
    Nightstalker          = Spell(14062),
    ShadowFocus           = Spell(108209),
    Subterfuge            = Spell(108208),
    VenomRush             = Spell(152152),
    Vigor                 = Spell(14983),
    -- Artifact
    Kingsbane             = Spell(192759),
    SilenceoftheUncrowned = Spell(241152),
    SinisterCirculation   = Spell(238138),
    SlayersPrecision      = Spell(214928),
    SurgeofToxins         = Spell(192425),
    UrgetoKill            = Spell(192384),
    -- Defensive
    CrimsonVial           = Spell(185311),
    Feint                 = Spell(1966),
    -- Utility
    Kick                  = Spell(1766),
    Sprint                = Spell(2983),
    -- Poisons
    AgonizingPoison       = Spell(200802),
    AgonizingPoisonDebuff = Spell(200803),
    CripplingPoison       = Spell(3408),
    DeadlyPoison          = Spell(2823),
    DeadlyPoisonDebuff    = Spell(2818),
    LeechingPoison        = Spell(108211),
    WoundPoison           = Spell(8679),
    -- Legendaries
    DreadlordsDeceit      = Spell(228224),
    -- Tier
    MutilatedFlesh        = Spell(211672),
    -- Misc
    PoolEnergy            = Spell(9999000010)
  };
  local S = Spell.Rogue.Assassination;
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Assassination = {
    -- Legendaries
    DraughtofSouls                = Item(140808, {13, 14}),
    InsigniaofRavenholdt          = Item(137049, {11, 12}),
    MantleoftheMasterAssassin     = Item(144236, {3})
  };
  local I = Item.Rogue.Assassination;
-- Rotation Var
  local ShouldReturn, ShouldReturn2; -- Used to get the return string
  local BestUnit, BestUnitTTD; -- Used for cycling
  local CountA, CountB; -- Used for potential Rupture units
  local RuptureThreshold; -- Used to compute the Rupture threshold (Cycling Performance)
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Rogue.Commons,
    Assassination = AR.GUISettings.APL.Rogue.Assassination
  };

-- APL Action Lists (and Variables)
-- actions=variable,name=energy_targetbleed_regen,value=energy.regen+bleeds*(7+talent.venom_rush.enabled*3)%2
local function Energy_TargetBleed_Regen ()
  return Player:EnergyRegen() + Rogue.Bleeds() * (7 + (S.VenomRush:IsAvailable() and 3 or 0)) / 2;
end
-- # Builders
local function Build ()
  if S.Hemorrhage:IsCastable() then
    -- actions.build=hemorrhage,if=refreshable
    if Target:IsInRange(5) and Target:DebuffRefreshable(S.Hemorrhage, 6) then
      if AR.Cast(S.Hemorrhage) then return "Cast"; end
    end
    -- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+talent.agonizing_poison.enabled+(talent.agonizing_poison.enabled&equipped.insignia_of_ravenholdt)
    if AR.AoEON() and Cache.EnemiesCount[8] < 2 + (Player:Buff(S.AgonizingPoison) and 1 or 0) + (Player:Buff(S.AgonizingPoison) and I.InsigniaofRavenholdt:IsEquipped() and 1 or 0) then
      BestUnit, BestUnitTTD = nil, 0;
      for Key, Value in pairs(Cache.Enemies[5]) do
        if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and Value:TimeToDie() > BestUnitTTD and Value:DebuffRefreshable(S.Hemorrhage, 6) and Value:Debuff(S.Rupture) then
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Hemorrhage);
      end
    end
  end
  -- actions.build+=/fan_of_knives,if=spell_targets>=2+talent.agonizing_poison.enabled+(talent.agonizing_poison.enabled&equipped.insignia_of_ravenholdt)|buff.the_dreadlords_deceit.stack>=29
  if S.FanofKnives:IsCastable() and (Cache.EnemiesCount[8] >= 2 + (Player:Buff(S.AgonizingPoison) and 1 or 0) + (Player:Buff(S.AgonizingPoison) and I.InsigniaofRavenholdt:IsEquipped() and 1 or 0) or (AR.AoEON() and Target:IsInRange(5) and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
    if AR.Cast(S.FanofKnives) then return "Cast"; end
  end
  if S.Mutilate:IsCastable() then
    -- actions.build+=/mutilate,cycle_targets=1,if=(!talent.agonizing_poison.enabled&dot.deadly_poison_dot.refreshable)|(talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<debuff.agonizing_poison.duration*0.3)
    if Target:IsInRange(5) and ((Player:Buff(S.DeadlyPoison) and Target:DebuffRefreshable(S.DeadlyPoisonDebuff, 4)) or (Player:Buff(S.AgonizingPoison) and Target:DebuffRefreshable(S.AgonizingPoisonDebuff, 4))) then
      if AR.Cast(S.Mutilate) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD = nil, 0;
      for Key, Value in pairs(Cache.Enemies[5]) do
        if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and Value:TimeToDie() > BestUnitTTD
          and ((Player:Buff(S.DeadlyPoison) and Value:DebuffRefreshable(S.DeadlyPoisonDebuff, 4))
            or (Player:Buff(S.AgonizingPoison) and Value:DebuffRefreshable(S.AgonizingPoisonDebuff, 4))) then
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Mutilate);
      end
    end
    -- actions.build+=/mutilate,if=energy.deficit<=25+variable.energy_targetbleed_regen|debuff.vendetta.up|dot.kingsbane.ticking|cooldown.vendetta.remains<=6|target.time_to_die<=6
    -- TODO: Fast double rupture for exsanguinate, check exsang cd ?
    if Target:IsInRange(5) and
      (Player:EnergyDeficit() <= 25+Energy_TargetBleed_Regen() or Target:Debuff(S.Vendetta) or Target:Debuff(S.Kingsbane) 
        or (AR.CDsON() and not S.Exsanguinate:IsOnCooldown()) or Target:TimeToDie() < 6
        or (AR.CDsON() and S.Vendetta:Cooldown() <= 6)) then
      if AR.Cast(S.Mutilate) then return "Cast"; end
    end
  end
  return false;
end
-- # Cooldowns
local function CDs ()
  if Target:IsInRange(5) then
    -- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|debuff.vendetta.up&cooldown.vanish.remains<5
    -- actions.cds+=/use_item,name=draught_of_souls,if=energy.deficit>=35+variable.energy_targetbleed_regen*2&(!equipped.mantle_of_the_master_assassin|cooldown.vanish.remains>8)&(!talent.agonizing_poison.enabled|debuff.agonizing_poison.stack>=5&debuff.surge_of_toxins.remains>=3)
    -- TODO: DoS 1
    -- actions.cds+=/use_item,name=draught_of_souls,if=mantle_duration>0&mantle_duration<3.5&dot.kingsbane.ticking
    -- TODO: DoS 2
    if Target:Debuff(S.Vendetta) then
      -- actions.cds+=/blood_fury,if=debuff.vendetta.up
      if S.BloodFury:IsCastable() then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.BloodFury) then return "Cast"; end
      end
      -- actions.cds+=/berserking,if=debuff.vendetta.up
      if S.Berserking:IsCastable() then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Berserking) then return "Cast"; end
      end
      -- actions.cds+=/arcane_torrent,if=dot.kingsbane.ticking&!buff.envenom.up&energy.deficit>=15+variable.energy_targetbleed_regen*gcd.remains*1.1
      if S.ArcaneTorrent:IsCastable() and Target:Debuff(S.Kingsbane) and not Player:Buff(S.Envenom) and Player:EnergyDeficit() > 15 + Energy_TargetBleed_Regen() * Player:GCDRemains() * 1.1 then
        if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
      end
    end
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
    if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
      AR.CastSuggested(S.MarkedforDeath);
    end
    -- actions.cds+=/vendetta,if=!artifact.urge_to_kill.enabled|energy.deficit>=60+variable.energy_targetbleed_regen
    if S.Vendetta:IsCastable() and (not S.UrgetoKill:ArtifactEnabled() or Player:EnergyDeficit() >= 60 + Energy_TargetBleed_Regen()) then
      if AR.Cast(S.Vendetta, Settings.Assassination.OffGCDasOffGCD.Vendetta) then return "Cast"; end
    end
    if S.Vanish:IsCastable() and not Player:IsTanking(Target) then
      if S.Nightstalker:IsAvailable() and Player:ComboPoints() >= Rogue.CPMaxSpend() then
        if not S.Exsanguinate:IsAvailable() then
          -- # Nightstalker w/o Exsanguinate: Vanish Envenom if Mantle & T19_4PC, else Vanish Rupture
          -- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&!talent.exsanguinate.enabled&((equipped.mantle_of_the_master_assassin&set_bonus.tier19_4pc&mantle_duration=0)|((!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(dot.rupture.refreshable|debuff.vendetta.up)))
          if (I.MantleoftheMasterAssassin:IsEquipped() and AC.Tier19_4Pc and Rogue.MantleDuration() == 0)
            or ((not I.MantleoftheMasterAssassin:IsEquipped() or not AC.Tier19_4Pc) and (Target:DebuffRefreshable(S.Rupture, RuptureThreshold) or Target:Debuff(S.Vendetta))) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        else
          -- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10)
          if S.Exsanguinate:IsAvailable() and S.Exsanguinate:Cooldown() < 1 and (Target:Debuff(S.Rupture) or AC.CombatTime() > 10) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        end
      end
      if S.Subterfuge:IsAvailable() then
        if I.MantleoftheMasterAssassin:IsEquipped() then
          -- actions.cds+=/vanish,if=talent.subterfuge.enabled&equipped.mantle_of_the_master_assassin&(debuff.vendetta.up|target.time_to_die<10)&mantle_duration=0
          if (Target:Debuff(S.Vendetta) or Target:TimeToDie() < 10) and Rogue.MantleDuration() == 0 then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        else
          -- actions.cds+=/vanish,if=talent.subterfuge.enabled&!equipped.mantle_of_the_master_assassin&!stealthed.rogue&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
          if not Player:IsStealthed(true, false) and Target:DebuffRefreshable(S.Garrote, 5.4) and ((Cache.EnemiesCount[8] <= 3 and Player:ComboPointsDeficit() >= 1+Cache.EnemiesCount[8]) or (Cache.EnemiesCount[8] >= 4 and Player:ComboPointsDeficit() >= 4)) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        end
      end
      -- actions.cds+=/vanish,if=talent.shadow_focus.enabled&energy.time_to_max>=2&combo_points.deficit>=4
      if S.ShadowFocus:IsAvailable() and Player:EnergyTimeToMax() >= 2 and Player:ComboPoints() >= 4 then
        if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
      end
    end
    -- actions.cds+=/exsanguinate,if=prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend
    if S.Exsanguinate:IsCastable() and S.Rupture:TimeSinceLastDisplay() < 2 and Target:DebuffRemains(S.Rupture) > 4+4*Rogue.CPMaxSpend() then
      if AR.Cast(S.Exsanguinate) then return "Cast"; end
    end
  end
  return false;
end
-- # Finishers
local function Finish ()
  -- actions.finish=death_from_above,if=combo_points>=5
  if S.DeathfromAbove:IsCastable() and Target:IsInRange(15) and Player:ComboPoints() >= 5 then
    if AR.Cast(S.DeathfromAbove) then return "Cast"; end
  end
  if S.Envenom:IsCastable() and Target:IsInRange(5) then
    -- actions.finish+=/envenom,if=combo_points>=4&(debuff.vendetta.up|debuff.surge_of_toxins.remains<gcd.remains+0.2)
    if Player:ComboPoints() >= 4 and (Target:Debuff(S.Vendetta) or Target:DebuffRemains(S.SurgeofToxins) < Player:GCDRemains() + 0.2) then
      if AR.Cast(S.Envenom) then return "Cast"; end
    end
    -- actions.finish+=/envenom,if=talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<gcd.remains+0.2
    if S.ElaboratePlanning:IsAvailable() and Player:ComboPoints() >= 3+(S.Exsanguinate:IsAvailable() and 0 or 1) and Player:BuffRemains(S.ElaboratePlanningBuff) < Player:GCDRemains()+0.2 then
      if AR.Cast(S.Envenom) then return "Cast"; end
    end
  end
  return false;
end
-- # Maintain
local function Maintain ()
  if Player:IsStealthed(true, false) then
    -- actions.maintain=rupture,if=talent.nightstalker.enabled&stealthed.rogue&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(talent.exsanguinate.enabled|target.time_to_die-remains>4)
    if S.Rupture:IsCastable() and Target:IsInRange(5) and S.Nightstalker:IsAvailable() and (not I.MantleoftheMasterAssassin:IsEquipped() or not AC.Tier19_4Pc)
      and (S.Exsanguinate:IsAvailable() or Target:TimeToDie()-Target:DebuffRemains(S.Garrote) > 4) then
      if AR.Cast(S.Rupture) then return "Cast"; end
    end
    -- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
    if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() and Player:ComboPointsDeficit() >= 1 then
      if Target:IsInRange(5) and Target:DebuffRefreshable(S.Garrote, 5.4) and (not AC.Exsanguinated(Target, "Garrote") or Target:DebuffRemains(S.Garrote) <= 1.5)
        and Target:TimeToDie()-Target:DebuffRemains(S.Garrote) > 4 then
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
          AR.CastLeftNameplate(BestUnit, S.Garrote);
        end
      end
    end
    -- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&remains<=10&!exsanguinated&target.time_to_die-remains>4
    if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() and Player:ComboPointsDeficit() >= 1 then
      if Target:IsInRange(5) and Target:DebuffRemains(S.Garrote) <= 10 and not AC.Exsanguinated(Target, "Garrote")
        and Target:TimeToDie()-Target:DebuffRemains(S.Garrote) > 4 then
        if AR.Cast(S.Garrote) then return "Cast"; end
      end
      if AR.AoEON() then
        BestUnit, BestUnitTTD = nil, 4;
        for Key, Value in pairs(Cache.Enemies[5]) do
          if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and Value:TimeToDie()-Value:DebuffRemains(S.Garrote) > BestUnitTTD
              and Value:DebuffRemains(S.Garrote) <= 10 and not AC.Exsanguinated(Value, "Garrote") then
              BestUnit, BestUnitTTD = Value, Value:TimeToDie();
          end
        end
        if BestUnit then
          AR.CastLeftNameplate(BestUnit, S.Garrote);
        end
      end
    end
  end
  -- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&combo_points>=3&!ticking&mantle_duration<=gcd.remains+0.2&target.time_to_die>4
  if S.Rupture:IsCastable() and Target:IsInRange(5) and not S.Exsanguinate:IsAvailable() and Player:ComboPoints() >= 3 and not Target:Debuff(S.Rupture) and Rogue.MantleDuration() <= Player:GCDRemains() + 0.2 and Target:TimeToDie() > 4 then
    if AR.Cast(S.Rupture) then return "Cast"; end
  end
  -- actions.maintain+=/rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
  -- TODO: Test 4-5 cp rupture for Exsg
  if AR.CDsON() and S.Rupture:IsCastable() and Target:IsInRange(5) and S.Exsanguinate:IsAvailable() and ((Player:ComboPoints() >= Rogue.CPMaxSpend() and S.Exsanguinate:Cooldown() < 1) 
    or (not Target:Debuff(S.Rupture) and (AC.CombatTime() > 10 or (Player:ComboPoints() >= 2+(S.UrgetoKill:ArtifactEnabled() and 1 or 0))))) then
    if AR.Cast(S.Rupture) then return "Cast"; end
  end
  -- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
  if Player:ComboPoints() >= 4 then
    if Target:IsInRange(5) and Target:DebuffRefreshable(S.Rupture, RuptureThreshold) and (not AC.Exsanguinated(Target, "Rupture") or Target:DebuffRemains(S.Rupture) <= 1.5)
      and Target:TimeToDie()-Target:DebuffRemains(S.Rupture) > 4 then
      if AR.Cast(S.Rupture) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD = nil, 4;
      for Key, Value in pairs(Cache.Enemies[5]) do
        if not Value:IsFacingBlacklisted() and Value:TimeToDie() < 7777 and Value:TimeToDie()-Value:DebuffRemains(S.Rupture) > BestUnitTTD
          and Value:DebuffRefreshable(S.Rupture, RuptureThreshold) and (not AC.Exsanguinated(Value, "Rupture") or Value:DebuffRemains(S.Rupture) <= 1.5) then
          BestUnit, BestUnitTTD = Value, Value:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Rupture);
      end
    end
  end
  if AR.CDsON() and S.Kingsbane:IsCastable() and Target:IsInRange(5) and Player:ComboPointsDeficit() >= 1 + (Rogue.MantleDuration() > Player:GCDRemains() + 0.2 and 1 or 0) then
    -- # Sinister Circulation makes it worth to cast Kingsbane on CD, although you shouldn't cast it if you're [stealthed w/ Nighstalker and have Mantle & T19_4PC to Envenom].
    -- actions.maintain+=/kingsbane,if=artifact.sinister_circulation.enabled&combo_points.deficit>=1+(mantle_duration>gcd.remains+0.2)&(talent.subterfuge.enabled|!stealthed.rogue|(talent.nightstalker.enabled&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)))
    if S.SinisterCirculation:IsAvailable() and
      (S.Subterfuge:IsAvailable() or not Player:IsStealthed(true, false)
        or (S.Nighstalker:IsAvailable() and (not I.MantleoftheMasterAssassin:IsEquipped() or not AC.Tier19_4Pc))) then
      if AR.Cast(S.Kingsbane) then return "Cast"; end
    end
    -- actions.maintain+=/kingsbane,if=!talent.exsanguinate.enabled&combo_points.deficit>=1+(mantle_duration>gcd.remains+0.2)&buff.envenom.up&((debuff.vendetta.up&debuff.surge_of_toxins.up)|cooldown.vendetta.remains<=5.2)
    if not S.Exsanguinate:IsAvailable() and Player:Buff(S.Envenom) and ((Target:Debuff(S.Vendetta) and Target:Debuff(S.SurgeofToxins)) or S.Vendetta:Cooldown() <= 5.2) then
      if AR.Cast(S.Kingsbane) then return "Cast"; end
    end
    -- actions.maintain+=/kingsbane,if=talent.exsanguinate.enabled&combo_points.deficit>=1+(mantle_duration>gcd.remains+0.2)&dot.rupture.exsanguinated
    if S.Exsanguinate:IsAvailable() and AC.Exsanguinated(Target, "Rupture") then
      if AR.Cast(S.Kingsbane) then return "Cast"; end
    end
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
  AC.GetEnemies(8); -- Fan of Knives & Death from Above
  AC.GetEnemies(5); -- Melee
  AR.Commons.AoEToggleEnemiesUpdate();
  -- Defensives
    -- Crimson Vial
    ShouldReturn = Rogue.CrimsonVial(S.CrimsonVial);
    if ShouldReturn then return ShouldReturn; end
    -- Feint
    ShouldReturn = Rogue.Feint(S.Feint);
    if ShouldReturn then return ShouldReturn; end
  -- Poisons
    -- Lethal Poison
    if Player:BuffRemains(S.DeadlyPoison) < Settings.Assassination.PoisonRefresh and Player:BuffRemains(S.WoundPoison) < Settings.Assassination.PoisonRefresh and Player:BuffRemains(S.AgonizingPoison) < Settings.Assassination.PoisonRefresh then
      if S.AgonizingPoison:IsAvailable() then
        AR.CastSuggested(S.AgonizingPoison);
      else
        AR.CastSuggested(S.DeadlyPoison);
      end
    end
    -- Non-Lethal Poison
    if Player:BuffRemains(S.CripplingPoison) < Settings.Assassination.PoisonRefresh and Player:BuffRemains(S.LeechingPoison) < Settings.Assassination.PoisonRefresh then
      if S.LeechingPoison:IsAvailable() then
        AR.CastSuggested(S.LeechingPoison);
      else
        AR.CastSuggested(S.CripplingPoison);
      end
    end
  -- Out of Combat
    if not Player:AffectingCombat() then
      -- Stealth
      ShouldReturn = Rogue.Stealth(S.Stealth);
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
    Rogue.MfDSniping(S.MarkedforDeath);
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
      -- Rupture Threshold Compute (Checked in Maintain and Finish Action List Call)
      RuptureThreshold = (4 + Player:ComboPoints() * 4) * 0.3;
      -- actions=call_action_list,name=cds
      if AR.CDsON() then
        ShouldReturn = CDs();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=maintain
      ShouldReturn = Maintain();
      if ShouldReturn then return ShouldReturn; end
      -- # The 'active_dot.rupture>=spell_targets.rupture' means that we don't want to envenom as long as we can multi-rupture (i.e. units that don't have rupture yet).
      -- Note: We disable 'active_dot.rupture>=spell_targets.rupture' in the addon since Multi-Dotting is suggested and not forced (CastLeftNameplate).
      -- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)&(!dot.rupture.refreshable|(dot.rupture.exsanguinated&dot.rupture.remains>=3.5)|target.time_to_die-dot.rupture.remains<=4)&active_dot.rupture>=spell_targets.rupture
      if (not AR.CDsON() or not S.Exsanguinate:IsAvailable() or S.Exsanguinate:Cooldown() > 2)
        and (not Target:DebuffRefreshable(S.Rupture, RuptureThreshold) or (AC.Exsanguinated(Target, "Rupture") and Target:DebuffRemains(S.Rupture) >= 3.5)
          or Target:TimeToDie()-Target:DebuffRemains(S.Rupture) <= 4) then
        ShouldReturn = Finish();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=build,if=combo_points.deficit>0|energy.deficit<=25+variable.energy_targetbleed_regen
      if Player:ComboPointsDeficit() > 0 or Player:EnergyDeficit() <= 25+Energy_TargetBleed_Regen() then
        ShouldReturn = Build();
        if ShouldReturn then return ShouldReturn; end
      end
      -- Poisoned Knife Out of Range [EnergyCap] or [PoisonRefresh]
      if S.PoisonedKnife:IsCastable() and Target:IsInRange(30) and not Player:IsStealthed(true, true)
        and ((not Target:IsInRange(10) and Player:EnergyTimeToMax() <= Player:GCD()*1.2)
          or (not Target:IsInRange(5) and ((Player:Buff(S.DeadlyPoison) and Target:DebuffRefreshable(S.DeadlyPoisonDebuff, 4))
            or (Player:Buff(S.AgonizingPoison) and Target:DebuffRefreshable(S.AgonizingPoisonDebuff, 4))))) then
        if AR.Cast(S.PoisonedKnife) then return "Cast Poisoned Knife"; end
      end
      -- Trick to take in consideration the Recovery Setting
      if S.Mutilate:IsCastable() and Target:IsInRange(5) then
        if AR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
      end
    end
end

AR.SetAPL(259, APL);

-- Last Update: 04/01/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,name=flask_of_the_seventh_demon
-- actions.precombat+=/augmentation,name=defiled
-- actions.precombat+=/food,name=lavish_suramar_feast
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/apply_poison
-- actions.precombat+=/stealth
-- actions.precombat+=/potion,name=old_war
-- actions.precombat+=/marked_for_death,if=raid_event.adds.in>40

-- # Executed every time the actor is available.
-- actions=variable,name=energy_targetbleed_regen,value=energy.regen+bleeds*(7+talent.venom_rush.enabled*3)%2
-- actions+=/call_action_list,name=cds
-- actions+=/call_action_list,name=maintain
-- # The 'active_dot.rupture>=spell_targets.rupture' means that we don't want to envenom as long as we can multi-rupture (i.e. units that don't have rupture yet).
-- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)&(!dot.rupture.refreshable|(dot.rupture.exsanguinated&dot.rupture.remains>=3.5)|target.time_to_die-dot.rupture.remains<=4)&active_dot.rupture>=spell_targets.rupture
-- actions+=/call_action_list,name=build,if=combo_points.deficit>0|energy.deficit<=25+variable.energy_targetbleed_regen

-- # Builders
-- actions.build=hemorrhage,if=refreshable
-- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+talent.agonizing_poison.enabled+(talent.agonizing_poison.enabled&equipped.insignia_of_ravenholdt)
-- actions.build+=/fan_of_knives,if=spell_targets>=2+talent.agonizing_poison.enabled+(talent.agonizing_poison.enabled&equipped.insignia_of_ravenholdt)|buff.the_dreadlords_deceit.stack>=29
-- actions.build+=/mutilate,cycle_targets=1,if=(!talent.agonizing_poison.enabled&dot.deadly_poison_dot.refreshable)|(talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<debuff.agonizing_poison.duration*0.3)
-- actions.build+=/mutilate,if=energy.deficit<=25+variable.energy_targetbleed_regen|debuff.vendetta.up|dot.kingsbane.ticking|cooldown.vendetta.remains<=6|target.time_to_die<=6

-- # Cooldowns
-- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|debuff.vendetta.up&cooldown.vanish.remains<5
-- actions.cds+=/use_item,name=draught_of_souls,if=energy.deficit>=35+variable.energy_targetbleed_regen*2&(!equipped.mantle_of_the_master_assassin|cooldown.vanish.remains>8)&(!talent.agonizing_poison.enabled|debuff.agonizing_poison.stack>=5&debuff.surge_of_toxins.remains>=3)
-- actions.cds+=/use_item,name=draught_of_souls,if=mantle_duration>0&mantle_duration<3.5&dot.kingsbane.ticking
-- actions.cds+=/blood_fury,if=debuff.vendetta.up
-- actions.cds+=/berserking,if=debuff.vendetta.up
-- actions.cds+=/arcane_torrent,if=dot.kingsbane.ticking&!buff.envenom.up&energy.deficit>=15+variable.energy_targetbleed_regen*gcd.remains*1.1
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
-- actions.cds+=/vendetta,if=!artifact.urge_to_kill.enabled|energy.deficit>=60+variable.energy_targetbleed_regen
-- # Nightstalker w/o Exsanguinate: Vanish Envenom if Mantle & T19_4PC, else Vanish Rupture
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&!talent.exsanguinate.enabled&((equipped.mantle_of_the_master_assassin&set_bonus.tier19_4pc&mantle_duration=0)|((!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(dot.rupture.refreshable|debuff.vendetta.up)))
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10)
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&equipped.mantle_of_the_master_assassin&(debuff.vendetta.up|target.time_to_die<10)&mantle_duration=0
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&!equipped.mantle_of_the_master_assassin&!stealthed.rogue&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
-- actions.cds+=/vanish,if=talent.shadow_focus.enabled&energy.time_to_max>=2&combo_points.deficit>=4
-- actions.cds+=/exsanguinate,if=prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend

-- # Finishers
-- actions.finish=death_from_above,if=combo_points>=5
-- actions.finish+=/envenom,if=combo_points>=4&(debuff.vendetta.up|debuff.surge_of_toxins.remains<gcd.remains+0.2)
-- actions.finish+=/envenom,if=talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<gcd.remains+0.2

-- # Maintain
-- actions.maintain=rupture,if=talent.nightstalker.enabled&stealthed.rogue&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(talent.exsanguinate.enabled|target.time_to_die-remains>4)
-- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
-- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&remains<=10&!exsanguinated&target.time_to_die-remains>4
-- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&combo_points>=3&!ticking&mantle_duration<=gcd.remains+0.2&target.time_to_die>4
-- actions.maintain+=/rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
-- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
-- # Sinister Circulation makes it worth to cast Kingsbane on CD, although you shouldn't cast it if you're [stealthed w/ Nighstalker and have Mantle & T19_4PC to Envenom].
-- actions.maintain+=/kingsbane,if=artifact.sinister_circulation.enabled&combo_points.deficit>=1+(mantle_duration>gcd.remains+0.2)&(talent.subterfuge.enabled|!stealthed.rogue|(talent.nightstalker.enabled&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)))
-- actions.maintain+=/kingsbane,if=!talent.exsanguinate.enabled&combo_points.deficit>=1+(mantle_duration>gcd.remains+0.2)&buff.envenom.up&((debuff.vendetta.up&debuff.surge_of_toxins.up)|cooldown.vendetta.remains<=5.2)
-- actions.maintain+=/kingsbane,if=talent.exsanguinate.enabled&combo_points.deficit>=1+(mantle_duration>gcd.remains+0.2)&dot.rupture.exsanguinated
-- actions.maintain+=/pool_resource,for_next=1
-- actions.maintain+=/garrote,cycle_targets=1,if=combo_points.deficit>=1&refreshable&(!exsanguinated|remains<=1.5)&target.time_to_die-remains>4
