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
  local Everyone = AR.Commons.Everyone;
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
    InternalBleeding      = Spell(154953),
    MarkedforDeath        = Spell(137619),
    MasterPoisoner        = Spell(196864),
    Nightstalker          = Spell(14062),
    ShadowFocus           = Spell(108209),
    Subterfuge            = Spell(108208),
    VenomRush             = Spell(152152),
    Vigor                 = Spell(14983),
    -- Artifact
    Kingsbane             = Spell(192759),
    MasterAssassin        = Spell(192349),
    SilenceoftheUncrowned = Spell(241152),
    SinisterCirculation   = Spell(238138),
    SlayersPrecision      = Spell(214928),
    SurgeofToxins         = Spell(192425),
    ToxicBlades           = Spell(192310),
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
    WoundPoisonDebuff     = Spell(8680),
    -- Legendaries
    DreadlordsDeceit      = Spell(228224),
    -- Tier
    MutilatedFlesh        = Spell(211672),
    -- Misc
    PoolEnergy            = Spell(9999000010)
  };
  local S = Spell.Rogue.Assassination;
  S.Envenom:RegisterDamage(
    -- Envenom DMG Formula:
    --  AP * CP * Env_APCoef * AssaResolv_M * Aura_M * ToxicB_M * T19_4PC_M * DS_M * AgoP_M * Mastery_M * Versa_M * SlayersPrecision_M * SiUncrowned_M
    -- 35037 * 5 * 0.6 * 1.17 * 1.11 * 1.16 * 1 * 1 * 1 * 2.443 * 1.0767 * 1.05 * 1.1
    function ()
      return
        -- Attack Power
        Player:AttackPower() *
        -- Combo Points
        Rogue.CPSpend() *
        -- Envenom AP Coef
        0.60 *
        -- Assassin's Resolve (SpellID: 84601)
        1.17 *
        -- Aura Multiplier (SpellID: 137037)
        1.11 *
        -- Toxic Blades Multiplier
        (S.ToxicBlades:ArtifactEnabled() and 1 + S.ToxicBlades:ArtifactRank()*0.03 or 1) *
        -- Tier 19 4PC  Multiplier
        (AC.Tier19_4Pc and Rogue.Assa_T19_4PC_EnvMultiplier() or 1) *
        -- Deeper Stratagem Multiplier
        (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
        -- Agonizing Poison Multiplier
        (Target:Debuff(S.AgonizingPoisonDebuff) and 1 + Target:Debuff(S.AgonizingPoisonDebuff, 17) / 100 or 1) *
        -- Mastery Finisher Multiplier
        (1 + Player:MasteryPct()/100) *
        -- Versatility Damage Multiplier
        (1 + Player:VersatilityDmgPct()/100) *
        -- Slayer's Precision Multiplier
        (S.SlayersPrecision:ArtifactEnabled() and 1.05 or 1) *
        -- Silence of the Uncrowned Multiplier
        (S.SilenceoftheUncrowned:ArtifactEnabled() and 1.1 or 1);
    end
  );
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Assassination = {
    -- Legendaries
    ConvergenceofFates            = Item(140806, {13, 14}),
    DuskwalkersFootpads           = Item(137030, {8}),
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
  local BleedTickTime, ExsanguinatedBleedTickTime = 2, 1;
  local RuptureDMGThreshold, GarroteDMGThreshold;
-- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Rogue.Commons,
    Assassination = AR.GUISettings.APL.Rogue.Assassination
  };

-- APL Action Lists (and Variables)
-- actions=variable,name=energy_regen_combined,value=energy.regen+poisoned_bleeds*(7+talent.venom_rush.enabled*3)%2
local function Energy_Regen_Combined ()
  return Cache.Get("APLVar", "Energy_Regen_Combined",
                   function() return Player:EnergyRegen() + Rogue.PoisonedBleeds() * (7 + (S.VenomRush:IsAvailable() and 3 or 0)) / 2; end);
end
-- actions+=/variable,name=energy_time_to_max_combined,value=energy.deficit%variable.energy_regen_combined
local function Energy_Time_To_Max_Combined ()
  return Cache.Get("APLVar", "Energy_Time_To_Max_Combined",
                   function() return Player:EnergyDeficit() / Energy_Regen_Combined(); end);
end
-- # Builders
local function Build ()
  if S.Hemorrhage:IsCastable() then
    -- actions.build=hemorrhage,if=refreshable
    if Target:IsInRange(5) and Target:DebuffRefreshable(S.Hemorrhage, 6) then
      if AR.Cast(S.Hemorrhage) then return "Cast"; end
    end
    -- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+talent.agonizing_poison.enabled+equipped.insignia_of_ravenholdt
    if AR.AoEON() and Cache.EnemiesCount[8] < 2 + (Player:Buff(S.AgonizingPoison) and 1 or 0) + (I.InsigniaofRavenholdt:IsEquipped() and 1 or 0) then
      BestUnit, BestUnitTTD = nil, 0;
      for _, Unit in pairs(Cache.Enemies[5]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD)
          and Unit:DebuffRefreshable(S.Hemorrhage, 6) and Unit:Debuff(S.Rupture) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Hemorrhage);
      end
    end
  end
  -- actions.build+=/fan_of_knives,if=spell_targets>=2+talent.agonizing_poison.enabled+equipped.insignia_of_ravenholdt|buff.the_dreadlords_deceit.stack>=29
  if S.FanofKnives:IsCastable() and (Cache.EnemiesCount[8] >= 2 + (Player:Buff(S.AgonizingPoison) and 1 or 0) + (I.InsigniaofRavenholdt:IsEquipped() and 1 or 0) or (AR.AoEON() and Target:IsInRange(5) and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
    if AR.Cast(S.FanofKnives) then return "Cast"; end
  end
  if S.Mutilate:IsCastable() then
    -- actions.build+=/mutilate,cycle_targets=1,if=(!talent.agonizing_poison.enabled&dot.deadly_poison_dot.refreshable)|(talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<debuff.agonizing_poison.duration*0.3)
    if Target:IsInRange(5) and ((Player:Buff(S.DeadlyPoison) and Target:DebuffRefreshable(S.DeadlyPoisonDebuff, 4)) or (Player:Buff(S.AgonizingPoison) and Target:DebuffRefreshable(S.AgonizingPoisonDebuff, 4))) then
      if AR.Cast(S.Mutilate) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD = nil, 0;
      for _, Unit in pairs(Cache.Enemies[5]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD)
          and ((Player:Buff(S.DeadlyPoison) and Unit:DebuffRefreshable(S.DeadlyPoisonDebuff, 4))
            or (Player:Buff(S.AgonizingPoison) and Unit:DebuffRefreshable(S.AgonizingPoisonDebuff, 4))) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Mutilate);
      end
    end
    -- actions.build+=/mutilate,if=energy.deficit<=25+variable.energy_regen_combined|debuff.vendetta.up|dot.kingsbane.ticking|cooldown.exsanguinate.up|cooldown.vendetta.remains<=6|target.time_to_die<=6
    -- TODO: Fast double rupture for exsanguinate, check exsang cd ?
    if Target:IsInRange(5) and
      (Player:EnergyDeficit() <= 25 + Energy_Regen_Combined() or Target:Debuff(S.Vendetta) or Target:Debuff(S.Kingsbane)
        or (AR.CDsON() and S.Exsanguinate:CooldownUp()) or (AR.CDsON() and S.Vendetta:CooldownRemains() <= 6)
        or Target:FilteredTimeToDie("<", 6)
        or not Rogue.CanDoTUnit(Target, RuptureDMGThreshold)) then
      if AR.Cast(S.Mutilate) then return "Cast"; end
    end
  end
  -- actions.build+=/poisoned_knife,cycle_targets=1,if=talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<=gcd.max*2.5&debuff.agonizing_poison.stack>=5
  if S.PoisonedKnife:IsCastable() and Player:Buff(S.AgonizingPoison) then
    if Target:IsInRange(30) and Target:DebuffRemains(S.AgonizingPoisonDebuff) <= Player:GCD() * 2.5 and Target:DebuffStack(S.AgonizingPoisonDebuff) >= 5 then
      if AR.Cast(S.PoisonedKnife) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD = nil, 0;
      for _, Unit in pairs(Cache.Enemies[30]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD)
          and Unit:DebuffRemains(S.AgonizingPoisonDebuff) < Player:GCD() * 2.5 and Unit:DebuffStack(S.AgonizingPoisonDebuff) >= 5 then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.PoisonedKnife);
      end
    end
  end
  return false;
end
-- # Cooldowns
local function CDs ()
  if Target:IsInRange(5) then
    -- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|debuff.vendetta.up&cooldown.vanish.remains<5
    -- actions.cds+=/use_item,name=draught_of_souls,if=energy.deficit>=35+variable.energy_regen_combined*2&(!equipped.mantle_of_the_master_assassin|cooldown.vanish.remains>8)&(!talent.agonizing_poison.enabled|debuff.agonizing_poison.stack>=5&debuff.surge_of_toxins.remains>=3)
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
      -- actions.cds+=/arcane_torrent,if=dot.kingsbane.ticking&!buff.envenom.up&energy.deficit>=15+variable.energy_regen_combined*gcd.remains*1.1
      if S.ArcaneTorrent:IsCastable() and Target:Debuff(S.Kingsbane) and not Player:Buff(S.Envenom) and Player:EnergyDeficit() > 15 + Energy_Regen_Combined() * Player:GCDRemains() * 1.1 then
        if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
      end
    end
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
    if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
      AR.CastSuggested(S.MarkedforDeath);
    end
    -- actions.cds+=/vendetta,if=!artifact.urge_to_kill.enabled|energy.deficit>=60+variable.energy_regen_combined
    if S.Vendetta:IsCastable() and (not S.UrgetoKill:ArtifactEnabled() or Player:EnergyDeficit() >= 60 + Energy_Regen_Combined()) then
      if AR.Cast(S.Vendetta, Settings.Assassination.OffGCDasOffGCD.Vendetta) then return "Cast"; end
    end
    if S.Vanish:IsCastable() and not Player:IsTanking(Target) then
      if S.Nightstalker:IsAvailable() and Player:ComboPoints() >= Rogue.CPMaxSpend() then
        if not S.Exsanguinate:IsAvailable() then
          -- # Nightstalker w/o Exsanguinate: Vanish Envenom if Mantle & T19_4PC, else Vanish Rupture
          -- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&!talent.exsanguinate.enabled&((equipped.mantle_of_the_master_assassin&set_bonus.tier19_4pc&mantle_duration=0)|((!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(dot.rupture.refreshable|debuff.vendetta.up)))
          if (I.MantleoftheMasterAssassin:IsEquipped() and AC.Tier19_4Pc and Rogue.MantleDuration() == 0)
            or ((not I.MantleoftheMasterAssassin:IsEquipped() or not AC.Tier19_4Pc)
              and ((Target:DebuffRefreshable(S.Rupture, RuptureThreshold) and Rogue.CanDoTUnit(Target, RuptureDMGThreshold)) or Target:Debuff(S.Vendetta))) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        else
          -- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10)
          if S.Exsanguinate:IsAvailable() and S.Exsanguinate:CooldownRemains() < 1 and (Target:Debuff(S.Rupture) or AC.CombatTime() > 10) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        end
      end
      if S.Subterfuge:IsAvailable() then
        if I.MantleoftheMasterAssassin:IsEquipped() then
          -- actions.cds+=/vanish,if=talent.subterfuge.enabled&equipped.mantle_of_the_master_assassin&(debuff.vendetta.up|target.time_to_die<10)&mantle_duration=0
          if (Target:Debuff(S.Vendetta) or Target:FilteredTimeToDie("<", 10)) and Rogue.MantleDuration() == 0 then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        else
          -- actions.cds+=/vanish,if=talent.subterfuge.enabled&!equipped.mantle_of_the_master_assassin&!stealthed.rogue&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
          if not Player:IsStealthed(true, false) and Target:DebuffRefreshable(S.Garrote, 5.4) and ((Cache.EnemiesCount[8] <= 3 and Player:ComboPointsDeficit() >= 1+Cache.EnemiesCount[8]) or (Cache.EnemiesCount[8] >= 4 and Player:ComboPointsDeficit() >= 4)) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        end
      end
      -- actions.cds+=/vanish,if=talent.shadow_focus.enabled&variable.energy_time_to_max_combined>=2&combo_points.deficit>=4
      if S.ShadowFocus:IsAvailable() and Energy_Time_To_Max_Combined() >= 2 and Player:ComboPoints() >= 4 then
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
    -- actions.finish+=/envenom,if=combo_points>=4&(debuff.vendetta.up|mantle_duration>=gcd.remains+0.2|debuff.surge_of_toxins.remains<gcd.remains+0.2|energy.deficit<=25+variable.energy_regen_combined)
    if Player:ComboPoints() >= 4 and (Target:Debuff(S.Vendetta) or Rogue.MantleDuration() >= Player:GCDRemains() + 0.2
      or Target:DebuffRemains(S.SurgeofToxins) < Player:GCDRemains() + 0.2 or Player:EnergyDeficit() <= 25 + Energy_Regen_Combined()
      or not Rogue.CanDoTUnit(Target, RuptureDMGThreshold)) then
      if AR.Cast(S.Envenom) then return "Cast"; end
    end
    -- actions.finish+=/envenom,if=talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<gcd.remains+0.2
    if S.ElaboratePlanning:IsAvailable() and Player:ComboPoints() >= 3+(S.Exsanguinate:IsAvailable() and 0 or 1) and Player:BuffRemains(S.ElaboratePlanningBuff) < Player:GCDRemains()+0.2 then
      if AR.Cast(S.Envenom) then return "Cast"; end
    end
  end
  return false;
end
-- # Kingsbane
local function Kingsbane ()
  -- # Sinister Circulation makes it worth to cast Kingsbane on CD exceot if you're [stealthed w/ Nighstalker and have Mantle & T19_4PC to Envenom] or before vendetta if you have mantle during the opener.
  -- actions.kb=kingsbane,if=artifact.sinister_circulation.enabled&!(equipped.duskwalkers_footpads&equipped.convergence_of_fates&artifact.master_assassin.rank>=6)&(time>25|!equipped.mantle_of_the_master_assassin|(debuff.vendetta.up&debuff.surge_of_toxins.up))&(talent.subterfuge.enabled|!stealthed.rogue|(talent.nightstalker.enabled&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)))
  if S.SinisterCirculation:IsAvailable() and not (I.DuskwalkersFootpads:IsEquipped() and I.ConvergenceofFates:IsEquipped() and S.MasterAssassin:ArtifactRank() >= 6)
    and (AC.CombatTime() > 25 or not I.MantleoftheMasterAssassin:IsEquipped() or (Target:Debuff(S.Vendetta) and Target:Debuff(S.SurgeofToxins)))
    and (S.Subterfuge:IsAvailable() or not Player:IsStealthed(true, false)
      or (S.Nighstalker:IsAvailable() and (not I.MantleoftheMasterAssassin:IsEquipped() or not AC.Tier19_4Pc))) then
    if AR.Cast(S.Kingsbane) then return "Cast"; end
  end
  -- actions.kb+=/kingsbane,if=!talent.exsanguinate.enabled&buff.envenom.up&((debuff.vendetta.up&debuff.surge_of_toxins.up)|cooldown.vendetta.remains<=5.8|cooldown.vendetta.remains>=10)
  if not S.Exsanguinate:IsAvailable() and Player:Buff(S.Envenom)
    and ((Target:Debuff(S.Vendetta) and Target:Debuff(S.SurgeofToxins)) or S.Vendetta:CooldownRemains() <= 5.8 or S.Vendetta:CooldownRemains() >= 10) then
    if AR.Cast(S.Kingsbane) then return "Cast"; end
  end
  -- actions.kb+=/kingsbane,if=talent.exsanguinate.enabled&dot.rupture.exsanguinated
  if S.Exsanguinate:IsAvailable() and AC.Exsanguinated(Target, "Rupture") then
    if AR.Cast(S.Kingsbane) then return "Cast"; end
  end
end
-- # Maintain
local function Maintain ()
  if Player:IsStealthed(true, false) then
    -- actions.maintain=rupture,if=talent.nightstalker.enabled&stealthed.rogue&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(talent.exsanguinate.enabled|target.time_to_die-remains>4)
    if S.Rupture:IsCastable() and Target:IsInRange(5) and S.Nightstalker:IsAvailable() and (not I.MantleoftheMasterAssassin:IsEquipped() or not AC.Tier19_4Pc)
      and (S.Exsanguinate:IsAvailable() or (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.Rupture))
      and Rogue.CanDoTUnit(Target, RuptureDMGThreshold))) then
      if AR.Cast(S.Rupture) then return "Cast"; end
    end
    -- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&refreshable&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>2
    if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() and Player:ComboPointsDeficit() >= 1 then
      if Target:IsInRange(5) and Target:DebuffRefreshable(S.Garrote, 5.4) and (not AC.Exsanguinated(Target, "Garrote") or Target:DebuffRemains(S.Garrote) <= ExsanguinatedBleedTickTime*2)
        and (Target:FilteredTimeToDie(">", 2, -Target:DebuffRemains(S.Garrote))
          or Rogue.CanDoTUnit(Target, GarroteDMGThreshold)) then
        if AR.Cast(S.Garrote) then return "Cast"; end
      end
      if AR.AoEON() then
        BestUnit, BestUnitTTD = nil, 2;
        for _, Unit in pairs(Cache.Enemies[5]) do
          if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemains(S.Garrote))
              and Unit:DebuffRefreshable(S.Garrote, 5.4) and (not AC.Exsanguinated(Unit, "Garrote") or Unit:DebuffRemains(S.Garrote) <= ExsanguinatedBleedTickTime*2) then
              BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
          end
        end
        if BestUnit then
          AR.CastLeftNameplate(BestUnit, S.Garrote);
        end
      end
    end
    -- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&remains<=10&pmultiplier<=1&!exsanguinated&target.time_to_die-remains>2
    -- TODO: pmultiplier (core handler rather than rogue specific)
    if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() and Player:ComboPointsDeficit() >= 1 then
      if Target:IsInRange(5) and Target:DebuffRemains(S.Garrote) <= 10 and not AC.Exsanguinated(Target, "Garrote")
        and (Target:FilteredTimeToDie(">", 2, -Target:DebuffRemains(S.Garrote))
          or Rogue.CanDoTUnit(Target, GarroteDMGThreshold)) then
        if AR.Cast(S.Garrote) then return "Cast"; end
      end
      if AR.AoEON() then
        BestUnit, BestUnitTTD = nil, 2;
        for _, Unit in pairs(Cache.Enemies[5]) do
          if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemains(S.Garrote))
              and Unit:DebuffRemains(S.Garrote) <= 10 and not AC.Exsanguinated(Unit, "Garrote") then
              BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
          end
        end
        if BestUnit then
          AR.CastLeftNameplate(BestUnit, S.Garrote);
        end
      end
    end
  end
  -- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&combo_points>=3&!ticking&mantle_duration<=gcd.remains+0.2&target.time_to_die>6
  if S.Rupture:IsCastable() and Target:IsInRange(5) and not S.Exsanguinate:IsAvailable() and Player:ComboPoints() >= 3
    and not Target:Debuff(S.Rupture) and Rogue.MantleDuration() <= Player:GCDRemains() + 0.2 and Target:FilteredTimeToDie(">", 6)
    and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
    if AR.Cast(S.Rupture) then return "Cast"; end
  end
  -- actions.maintain+=/rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
  -- TODO: Test 4-5 cp rupture for Exsg
  if AR.CDsON() and S.Rupture:IsCastable() and Target:IsInRange(5) and S.Exsanguinate:IsAvailable() and ((Player:ComboPoints() >= Rogue.CPMaxSpend() and S.Exsanguinate:CooldownRemains() < 1) 
    or (not Target:Debuff(S.Rupture) and (AC.CombatTime() > 10 or (Player:ComboPoints() >= 2+(S.UrgetoKill:ArtifactEnabled() and 1 or 0))))) then
    if AR.Cast(S.Rupture) then return "Cast"; end
  end
  -- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>6
  -- TODO: pmultiplier (core handler rather than rogue specific)
  if Player:ComboPoints() >= 4 then
    if Target:IsInRange(5) and Target:DebuffRefreshable(S.Rupture, RuptureThreshold) and (not AC.Exsanguinated(Target, "Rupture") or Target:DebuffRemains(S.Rupture) <= 1.5)
      and Target:FilteredTimeToDie(">", 6, -Target:DebuffRemains(S.Rupture))
      and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
      if AR.Cast(S.Rupture) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD = nil, 6;
      for _, Unit in pairs(Cache.Enemies[5]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemains(S.Rupture))
          and Rogue.CanDoTUnit(Unit, RuptureDMGThreshold)
          and Unit:DebuffRefreshable(S.Rupture, RuptureThreshold) and (not AC.Exsanguinated(Unit, "Rupture") or Unit:DebuffRemains(S.Rupture) <= 1.5) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Rupture);
      end
    end
  end
  -- actions.maintain+=/call_action_list,name=kb,if=combo_points.deficit>=1+(mantle_duration>=gcd.remains+0.2)
  if AR.CDsON() and S.Kingsbane:IsCastable() and Target:IsInRange(5) and Player:ComboPointsDeficit() >= 1 + (Rogue.MantleDuration() > Player:GCDRemains() + 0.2 and 1 or 0) then
    return Kingsbane();
  end
  -- actions.maintain+=/garrote,cycle_targets=1,if=(!talent.subterfuge.enabled|!(cooldown.vanish.up&cooldown.vendetta.remains<=4))&combo_points.deficit>=1&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
  -- TODO: pmultiplier (core handler rather than rogue specific)
  if S.Garrote:IsCastable() and (not S.Subterfuge:IsAvailable() or not (S.Vanish:CooldownUp() and S.Vendetta:CooldownRemains() <= 4)) and Player:ComboPointsDeficit() >= 1 then
    if Target:IsInRange(5) and Target:DebuffRefreshable(S.Garrote, 5.4) and (not AC.Exsanguinated(Target, "Garrote") or Target:DebuffRemains(S.Garrote) <= 1.5)
        and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.Garrote))
          or Rogue.CanDoTUnit(Target, GarroteDMGThreshold)) then
      -- actions.maintain+=/pool_resource,for_next=1
      if Player:Energy() < 45 then
        if AR.Cast(S.PoolEnergy) then return "Pool for Garrote (ST)"; end
      end
      if AR.Cast(S.Garrote) then return "Cast"; end
    end
    if AR.AoEON() then
      BestUnit, BestUnitTTD = nil, 4;
      for _, Unit in pairs(Cache.Enemies[5]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemains(S.Garrote))
          and Unit:DebuffRefreshable(S.Garrote, 5.4) and (not AC.Exsanguinated(Unit, "Garrote") or Unit:DebuffRemains(S.Garrote) <= 1.5) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
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
  AC.GetEnemies(30); -- Used for Poisoned Knife Poison refresh
  AC.GetEnemies(8); -- Fan of Knives & Death from Above
  AC.GetEnemies(5); -- Melee
  Everyone.AoEToggleEnemiesUpdate();
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
      if Everyone.TargetIsValid() and Target:IsInRange(5) then
        if Player:ComboPoints() >= 5 then
          if S.Rupture:IsCastable() and not Target:Debuff(S.Rupture)
            and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
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
    if Everyone.TargetIsValid() then
      -- Mythic Dungeon
      ShouldReturn = MythicDungeon();
      if ShouldReturn then return ShouldReturn; end
      -- Training Scenario
      ShouldReturn = TrainingScenario();
      if ShouldReturn then return ShouldReturn; end
      -- Interrupts
      Everyone.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, {
        {S.Blind, "Cast Blind (Interrupt)", function () return true; end},
        {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return Player:ComboPoints() > 0; end}
      });
      -- Compute Cache
      RuptureThreshold = (4 + Player:ComboPoints() * 4) * 0.3;
      RuptureDMGThreshold = S.Envenom:Damage()*Settings.Assassination.EnvenomDMGOffset;
      GarroteDMGThreshold = S.Envenom:Damage()*Settings.Assassination.EnvenomDMGOffset/3;
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
      -- Note: We add 'Rogue.CanDoTUnit(Target, RuptureDMGThreshold)' to account for when Rupture isn't castable
      -- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)&(!dot.rupture.refreshable|(dot.rupture.exsanguinated&dot.rupture.remains>=3.5)|target.time_to_die-dot.rupture.remains<=4)&active_dot.rupture>=spell_targets.rupture
      if (not AR.CDsON() or not S.Exsanguinate:IsAvailable() or S.Exsanguinate:CooldownRemains() > 2)
        and (not Target:DebuffRefreshable(S.Rupture, RuptureThreshold) or (AC.Exsanguinated(Target, "Rupture") and Target:DebuffRemains(S.Rupture) >= 3.5)
          or Target:FilteredTimeToDie("<=", 4, -Target:DebuffRemains(S.Rupture))
          or not Rogue.CanDoTUnit(Target, RuptureDMGThreshold)) then
        ShouldReturn = Finish();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=build,if=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined
      if Player:ComboPointsDeficit() > 1 or Player:EnergyDeficit() <= 25 + Energy_Regen_Combined() then
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

-- Last Update: 04/13/2017

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
-- actions=variable,name=energy_regen_combined,value=energy.regen+poisoned_bleeds*(7+talent.venom_rush.enabled*3)%2
-- actions+=/variable,name=energy_time_to_max_combined,value=energy.deficit%variable.energy_regen_combined
-- actions+=/call_action_list,name=cds
-- actions+=/call_action_list,name=maintain
-- # The 'active_dot.rupture>=spell_targets.rupture' means that we don't want to envenom as long as we can multi-rupture (i.e. units that don't have rupture yet).
-- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)&(!dot.rupture.refreshable|(dot.rupture.exsanguinated&dot.rupture.remains>=3.5)|target.time_to_die-dot.rupture.remains<=4)&active_dot.rupture>=spell_targets.rupture
-- actions+=/call_action_list,name=build,if=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined

-- # Builders
-- actions.build=hemorrhage,if=refreshable
-- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+talent.agonizing_poison.enabled+equipped.insignia_of_ravenholdt
-- actions.build+=/fan_of_knives,if=spell_targets>=2+talent.agonizing_poison.enabled+equipped.insignia_of_ravenholdt|buff.the_dreadlords_deceit.stack>=29
-- actions.build+=/mutilate,cycle_targets=1,if=(!talent.agonizing_poison.enabled&dot.deadly_poison_dot.refreshable)|(talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<debuff.agonizing_poison.duration*0.3)
-- actions.build+=/mutilate,if=energy.deficit<=25+variable.energy_regen_combined|debuff.vendetta.up|dot.kingsbane.ticking|cooldown.exsanguinate.up|cooldown.vendetta.remains<=6|target.time_to_die<=6
-- actions.build+=/poisoned_knife,cycle_targets=1,if=talent.agonizing_poison.enabled&debuff.agonizing_poison.remains<=gcd.max*2.5&debuff.agonizing_poison.stack>=5

-- # Cooldowns
-- actions.cds=potion,name=old_war,if=buff.bloodlust.react|target.time_to_die<=25|debuff.vendetta.up&cooldown.vanish.remains<5
-- actions.cds+=/use_item,name=draught_of_souls,if=energy.deficit>=35+variable.energy_regen_combined*2&(!equipped.mantle_of_the_master_assassin|cooldown.vanish.remains>8)&(!talent.agonizing_poison.enabled|debuff.agonizing_poison.stack>=5&debuff.surge_of_toxins.remains>=3)
-- actions.cds+=/use_item,name=draught_of_souls,if=mantle_duration>0&mantle_duration<3.5&dot.kingsbane.ticking
-- actions.cds+=/blood_fury,if=debuff.vendetta.up
-- actions.cds+=/berserking,if=debuff.vendetta.up
-- actions.cds+=/arcane_torrent,if=dot.kingsbane.ticking&!buff.envenom.up&energy.deficit>=15+variable.energy_regen_combined*gcd.remains*1.1
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
-- actions.cds+=/vendetta,if=!artifact.urge_to_kill.enabled|energy.deficit>=60+variable.energy_regen_combined
-- # Nightstalker w/o Exsanguinate: Vanish Envenom if Mantle & T19_4PC, else Vanish Rupture
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&!talent.exsanguinate.enabled&((equipped.mantle_of_the_master_assassin&set_bonus.tier19_4pc&mantle_duration=0)|((!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(dot.rupture.refreshable|debuff.vendetta.up)))
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10)
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&equipped.mantle_of_the_master_assassin&(debuff.vendetta.up|target.time_to_die<10)&mantle_duration=0
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&!equipped.mantle_of_the_master_assassin&!stealthed.rogue&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
-- actions.cds+=/vanish,if=talent.shadow_focus.enabled&variable.energy_time_to_max_combined>=2&combo_points.deficit>=4
-- actions.cds+=/exsanguinate,if=prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend

-- # Finishers
-- actions.finish=death_from_above,if=combo_points>=5
-- actions.finish+=/envenom,if=combo_points>=4&(debuff.vendetta.up|mantle_duration>=gcd.remains+0.2|debuff.surge_of_toxins.remains<gcd.remains+0.2|energy.deficit<=25+variable.energy_regen_combined)
-- actions.finish+=/envenom,if=talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<gcd.remains+0.2

-- # Kingsbane
-- # Sinister Circulation makes it worth to cast Kingsbane on CD exceot if you're [stealthed w/ Nighstalker and have Mantle & T19_4PC to Envenom] or before vendetta if you have mantle during the opener.
-- actions.kb=kingsbane,if=artifact.sinister_circulation.enabled&!(equipped.duskwalkers_footpads&equipped.convergence_of_fates&artifact.master_assassin.rank>=6)&(time>25|!equipped.mantle_of_the_master_assassin|(debuff.vendetta.up&debuff.surge_of_toxins.up))&(talent.subterfuge.enabled|!stealthed.rogue|(talent.nightstalker.enabled&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)))
-- actions.kb+=/kingsbane,if=!talent.exsanguinate.enabled&buff.envenom.up&((debuff.vendetta.up&debuff.surge_of_toxins.up)|cooldown.vendetta.remains<=5.8|cooldown.vendetta.remains>=10)
-- actions.kb+=/kingsbane,if=talent.exsanguinate.enabled&dot.rupture.exsanguinated

-- # Maintain
-- actions.maintain=rupture,if=talent.nightstalker.enabled&stealthed.rogue&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(talent.exsanguinate.enabled|target.time_to_die-remains>4)
-- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&refreshable&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>2
-- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&remains<=10&pmultiplier<=1&!exsanguinated&target.time_to_die-remains>2
-- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&combo_points>=3&!ticking&mantle_duration<=gcd.remains+0.2&target.time_to_die>6
-- actions.maintain+=/rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
-- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>6
-- actions.maintain+=/call_action_list,name=kb,if=combo_points.deficit>=1+(mantle_duration>=gcd.remains+0.2)
-- actions.maintain+=/pool_resource,for_next=1
-- actions.maintain+=/garrote,cycle_targets=1,if=(!talent.subterfuge.enabled|!(cooldown.vanish.up&cooldown.vendetta.remains<=4))&combo_points.deficit>=1&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
