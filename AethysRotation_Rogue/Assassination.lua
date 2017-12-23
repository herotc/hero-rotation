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
    Stealth2              = Spell(115191), -- w/ Subterfuge Talent
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
    ToxicBlade            = Spell(245388),
    ToxicBladeDebuff      = Spell(245389),
    VenomRush             = Spell(152152),
    Vigor                 = Spell(14983),
    -- Artifact
    AssassinsBlades       = Spell(214368),
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
    Blind                 = Spell(2094),
    Kick                  = Spell(1766),
    Sprint                = Spell(2983),
    -- Poisons
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
-- Items
  if not Item.Rogue then Item.Rogue = {}; end
  Item.Rogue.Assassination = {
    -- Legendaries
    DuskwalkersFootpads           = Item(137030, {8}),
    DraughtofSouls                = Item(140808, {13, 14}),
    InsigniaofRavenholdt          = Item(137049, {11, 12}),
    MantleoftheMasterAssassin     = Item(144236, {3}),
    -- Trinkets
    ConvergenceofFates            = Item(140806, {13, 14}),
    DraughtofSouls                = Item(140808, {13, 14}),
    KiljaedensBurningWish         = Item(144259, {13, 14}),
    SpecterofBetrayal             = Item(151190, {13, 14}),
    UmbralMoonglaives             = Item(147012, {13, 14}),
    VialofCeaselessToxins         = Item(147011, {13, 14}),
  };
  local I = Item.Rogue.Assassination;
-- Spells Damage
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
        1.28 *
        -- Toxic Blade Multiplier
        (Target:Debuff(S.ToxicBladeDebuff) and 1.35 or 1) *
        -- Toxic Blades Multiplier
        (S.ToxicBlades:ArtifactEnabled() and 1 + S.ToxicBlades:ArtifactRank()*0.03 or 1) *
        -- Tier 19 4PC  Multiplier
        (AC.Tier19_4Pc and Rogue.Assa_T19_4PC_EnvMultiplier() or 1) *
        -- Deeper Stratagem Multiplier
        (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
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
  S.Mutilate:RegisterDamage(
    function ()
      -- TODO: Implement most of those thing in the core.
      local minDamage, maxDamage, minOffHandDamage, maxOffHandDamage, physicalBonusPos, physicalBonusNeg, percent = UnitDamage("player");
      local speed, offhandSpeed = UnitAttackSpeed("player");
      local wSpeed = speed * (1 + Player:HastePct()/100);
      local AvgWpnDmg = (minDamage + maxDamage) / 2 / wSpeed / percent - (Player:AttackPower() / 3.5);
      return
        -- (Average Weapon Damage [Weapon DPS * Swing Speed] + (Attack Power * NormalizedWeaponSpeed / 3.5)) * (MH Factor +OH Factor)
        (AvgWpnDmg * wSpeed + (Player:AttackPower() * 1.7 / 3.5)) * 1.5 *
        -- Mutilate Coefficient
        3.6 *
        -- Assassin's Resolve (SpellID: 84601)
        1.17 *
        -- Aura Multiplier (SpellID: 137037)
        1.28 *
        -- Assassin's Blades Multiplier
        (S.AssassinsBlades:ArtifactEnabled() and 1.15 or 1) *
        -- Versatility Damage Multiplier
        (1 + Player:VersatilityDmgPct()/100) *
        -- Slayer's Precision Multiplier
        (S.SlayersPrecision:ArtifactEnabled() and 1.05 or 1) *
        -- Silence of the Uncrowned Multiplier
        (S.SilenceoftheUncrowned:ArtifactEnabled() and 1.1 or 1) *
        -- Insignia of Ravenholdt Effect
        (I.InsigniaofRavenholdt:IsEquipped() and 1.3 or 1);
    end
  );
  local function NighstalkerMultiplier ()
    return S.Nightstalker:IsAvailable() and Player:IsStealthed(true, false) and 1.5 or 1;
  end
  S.Garrote:RegisterPMultiplier(
    {NighstalkerMultiplier},
    {function ()
      return S.Subterfuge:IsAvailable() and Player:IsStealthed(true, false) and 2.25 or 1;
    end}
  );
  S.Rupture:RegisterPMultiplier(
    {NighstalkerMultiplier}
  );
-- Rotation Var
  local ShouldReturn, ShouldReturn2; -- Used to get the return string
  local BleedTickTime, ExsanguinatedBleedTickTime = 2, 2/(1+1.5);
  local Stealth;
  local RuptureThreshold, RuptureDMGThreshold, GarroteDMGThreshold;
  local Energy_Regen_Combined, Energy_Time_To_Max_Combined;
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
    if Target:IsInRange("Melee") and Target:DebuffRefreshableP(S.Hemorrhage, 6) then
      if AR.Cast(S.Hemorrhage) then return "Cast"; end
    end
    -- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+equipped.insignia_of_ravenholdt
    if AR.AoEON() and Cache.EnemiesCount[10] < 2 + (I.InsigniaofRavenholdt:IsEquipped() and 1 or 0) then
      local BestUnit, BestUnitTTD = nil, 0;
      for _, Unit in pairs(Cache.Enemies["Melee"]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD)
          and Unit:DebuffRefreshableP(S.Hemorrhage, 6) and Unit:Debuff(S.Rupture) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Hemorrhage);
      end
    end
  end
  -- actions.build+=/fan_of_knives,if=spell_targets>=2+equipped.insignia_of_ravenholdt|buff.the_dreadlords_deceit.stack>=29
  if S.FanofKnives:IsCastable() and (Cache.EnemiesCount[10] >= 2 + (I.InsigniaofRavenholdt:IsEquipped() and 1 or 0) or (AR.AoEON() and Target:IsInRange("Melee") and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
    if AR.Cast(S.FanofKnives) then return "Cast"; end
  end
  if S.Mutilate:IsCastable() then
    -- actions.build+=/mutilate,cycle_targets=1,if=dot.deadly_poison_dot.refreshable
    if Target:IsInRange("Melee") and Target:DebuffRefreshableP(S.DeadlyPoisonDebuff, 4) then
      if AR.Cast(S.Mutilate) then return "Cast"; end
    end
    if AR.AoEON() then
      local BestUnit, BestUnitTTD = nil, 0;
      for _, Unit in pairs(Cache.Enemies["Melee"]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD)
          and Unit:DebuffRefreshableP(S.DeadlyPoisonDebuff, 4) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Mutilate);
      end
    end
    -- actions.build+=/mutilate
    if Target:IsInRange("Melee") then
      if AR.Cast(S.Mutilate) then return "Cast"; end
    end
  end
  return false;
end
-- # Cooldowns
local function CDs ()
  if Target:IsInRange("Melee") then
    -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|debuff.vendetta.up&cooldown.vanish.remains<5

    -- Trinkets
    local TrinketSuggested = false;
    if not TrinketSuggested and I.SpecterofBetrayal:IsEquipped() and I.SpecterofBetrayal:IsReady() then
      if AR.CastSuggested(I.SpecterofBetrayal) then TrinketSuggested = true; end
    end
    if not TrinketSuggested and I.UmbralMoonglaives:IsEquipped() and I.UmbralMoonglaives:IsReady() then
      if AR.CastSuggested(I.UmbralMoonglaives) then TrinketSuggested = true; end
    end
    if not TrinketSuggested and I.VialofCeaselessToxins:IsEquipped() and I.VialofCeaselessToxins:IsReady() then
      if AR.CastSuggested(I.VialofCeaselessToxins) then TrinketSuggested = true; end
    end
    if not TrinketSuggested and I.KiljaedensBurningWish:IsEquipped() and I.KiljaedensBurningWish:IsReady() then
      if AR.CastSuggested(I.KiljaedensBurningWish) then TrinketSuggested = true; end
    end

    -- Racials
    if Target:Debuff(S.Vendetta) then
      -- actions.cds+=/blood_fury,if=debuff.vendetta.up
      if S.BloodFury:IsCastable() then
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
      end
      -- actions.cds+=/berserking,if=debuff.vendetta.up
      if S.Berserking:IsCastable() then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
      end
      -- actions.cds+=/arcane_torrent,if=dot.kingsbane.ticking&!buff.envenom.up&energy.deficit>=15+variable.energy_regen_combined*gcd.remains*1.1
      -- Note: Temporarly modified the conditions
      if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficitPredicted() > 15 + Energy_Regen_Combined * Player:GCDRemains() * 1.1 then
        if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast"; end
      end
    end

    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
    if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
      AR.CastSuggested(S.MarkedforDeath);
    end
    -- actions.cds+=/vendetta,if=!talent.exsanguinate.enabled|dot.rupture.ticking
    if S.Vendetta:IsCastable() and (not S.Exsanguinate:IsAvailable() or Target:Debuff(S.Rupture)) then
      if AR.Cast(S.Vendetta, Settings.Assassination.OffGCDasOffGCD.Vendetta) then return "Cast"; end
    end
    if S.Exsanguinate:IsCastable() then
      if not AC.Tier20_4Pc then
        -- actions.cds+=/exsanguinate,if=!set_bonus.tier20_4pc&(prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend&!stealthed.rogue|dot.garrote.pmultiplier>1&!cooldown.vanish.up&buff.subterfuge.up)
        if Player:PrevGCD(1, S.Rupture) and Target:DebuffRemainsP(S.Rupture) > 4+4*Rogue.CPMaxSpend() and not Player:IsStealthed(true, false)
          or Target:PMultiplier(S.Garrote) > 1 and not S.Vanish:CooldownUp() and Player:Buff(S.Subterfuge) then
          if AR.Cast(S.Exsanguinate) then return "Cast"; end
        end
      else
        -- actions.cds+=/exsanguinate,if=set_bonus.tier20_4pc&dot.garrote.remains>20&dot.rupture.remains>4+4*cp_max_spend
        if Target:DebuffRemainsP(S.Garrote) > 20 and Target:DebuffRemainsP(S.Rupture) > 4+4*Rogue.CPMaxSpend() then
          if AR.Cast(S.Exsanguinate) then return "Cast"; end
        end
      end
    end
    if S.Vanish:IsCastable() and not Player:IsTanking(Target) then
      if S.Nightstalker:IsAvailable() and Player:ComboPoints() >= Rogue.CPMaxSpend() then
        if not S.Exsanguinate:IsAvailable() then
          -- # Nightstalker w/o Exsanguinate: Vanish Envenom if Mantle & T19_4PC, else Vanish Rupture
          -- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&!talent.exsanguinate.enabled&mantle_duration=0&((equipped.mantle_of_the_master_assassin&set_bonus.tier19_4pc)|((!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(dot.rupture.refreshable|debuff.vendetta.up)))
          if Rogue.MantleDuration() == 0 and ((I.MantleoftheMasterAssassin:IsEquipped() and AC.Tier19_4Pc)
            or ((not I.MantleoftheMasterAssassin:IsEquipped() or not AC.Tier19_4Pc)
              and ((Target:DebuffRefreshableP(S.Rupture, RuptureThreshold) and Rogue.CanDoTUnit(Target, RuptureDMGThreshold)) or Target:Debuff(S.Vendetta)))) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        else
          -- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10)
          if S.Exsanguinate:IsAvailable() and S.Exsanguinate:CooldownRemainsP() < 1 and (Target:Debuff(S.Rupture) or AC.CombatTime() > 10) then
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
          if not Player:IsStealthed(true, false) and Target:DebuffRefreshableP(S.Garrote, 5.4) and ((Cache.EnemiesCount[10] <= 3 and Player:ComboPointsDeficit() >= 1+Cache.EnemiesCount[10]) or (Cache.EnemiesCount[10] >= 4 and Player:ComboPointsDeficit() >= 4)) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
          end
        end
      end
      -- actions.cds+=/vanish,if=talent.shadow_focus.enabled&variable.energy_time_to_max_combined>=2&combo_points.deficit>=4
      if S.ShadowFocus:IsAvailable() and Energy_Time_To_Max_Combined >= 2 and Player:ComboPoints() >= 4 then
        if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast"; end
      end
    end
    -- actions.cds+=/toxic_blade,if=combo_points.deficit>=1+(mantle_duration>=0.2)&dot.rupture.remains>8&cooldown.vendetta.remains>10
    if S.ToxicBlade:IsCastable("Melee") and Player:ComboPointsDeficit() >= 1 + (Rogue.MantleDuration() > 0.2 and 1 or 0)
      and Target:DebuffRemainsP(S.Rupture) > 8 and S.Vendetta:CooldownRemainsP() > 10 then
      if AR.Cast(S.ToxicBlade) then return "Cast"; end
    end
  end
  return false;
end
-- # Finishers
local function Finish ()
  -- actions.finish=death_from_above,if=combo_points>=5
  if S.DeathfromAbove:IsCastable(15) and Player:ComboPoints() >= 5 then
    if AR.Cast(S.DeathfromAbove) then return "Cast"; end
  end
  if S.Envenom:IsCastable("Melee") then
    -- actions.finish+=/envenom,if=combo_points>=4+(talent.deeper_stratagem.enabled&!set_bonus.tier19_4pc)&(debuff.vendetta.up|mantle_duration>=0.2|debuff.surge_of_toxins.remains<0.2|energy.deficit<=25+variable.energy_regen_combined)
    if Player:ComboPoints() >= 4 + (S.DeeperStratagem:IsAvailable() and not AC.Tier19_4Pc and 1 or 0) and (Target:Debuff(S.Vendetta) or Rogue.MantleDuration() >= 0.2
      or Target:DebuffRemainsP(S.SurgeofToxins) < 0.2 or Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined
      or not Rogue.CanDoTUnit(Target, RuptureDMGThreshold)) then
      if AR.Cast(S.Envenom) then return "Cast"; end
    end
    -- actions.finish+=/envenom,if=talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<0.2
    if S.ElaboratePlanning:IsAvailable() and Player:ComboPoints() >= 3+(S.Exsanguinate:IsAvailable() and 0 or 1) and Player:BuffRemainsP(S.ElaboratePlanningBuff) < 0.2 then
      if AR.Cast(S.Envenom) then return "Cast"; end
    end
  end
  return false;
end
-- # Kingsbane
local function Kingsbane ()
  -- # Sinister Circulation makes it worth to cast Kingsbane on CD exceot if you're [stealthed w/ Nighstalker and have Mantle & T19_4PC to Envenom] or before vendetta if you have mantle during the opener.
  -- actions.kb=kingsbane,if=artifact.sinister_circulation.enabled&!(equipped.duskwalkers_footpads&equipped.convergence_of_fates&artifact.master_assassin.rank>=6)&(time>25|!equipped.mantle_of_the_master_assassin|(debuff.vendetta.up&debuff.surge_of_toxins.up))&(talent.subterfuge.enabled|!stealthed.rogue|(talent.nightstalker.enabled&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)))
  if S.SinisterCirculation:ArtifactEnabled() and not (I.DuskwalkersFootpads:IsEquipped() and I.ConvergenceofFates:IsEquipped() and S.MasterAssassin:ArtifactRank() >= 6)
    and (AC.CombatTime() > 25 or not I.MantleoftheMasterAssassin:IsEquipped() or (Target:Debuff(S.Vendetta) and Target:Debuff(S.SurgeofToxins)))
    and (S.Subterfuge:IsAvailable() or not Player:IsStealthed(true, false)
      or (S.Nighstalker:IsAvailable() and (not I.MantleoftheMasterAssassin:IsEquipped() or not AC.Tier19_4Pc))) then
    if AR.Cast(S.Kingsbane) then return "Cast"; end
  end
  -- actions.kb+=/kingsbane,if=buff.envenom.up&((debuff.vendetta.up&debuff.surge_of_toxins.up)|cooldown.vendetta.remains<=5.8|cooldown.vendetta.remains>=10)
  if Player:Buff(S.Envenom) and ((Target:Debuff(S.Vendetta) and Target:Debuff(S.SurgeofToxins)) or S.Vendetta:CooldownRemainsP() <= 5.8 or S.Vendetta:CooldownRemainsP() >= 10) then
    if AR.Cast(S.Kingsbane) then return "Cast"; end
  end
  return false;
end
-- # Maintain
local function Maintain ()
  if Player:IsStealthed(true, false) then
    -- actions.maintain=rupture,if=talent.nightstalker.enabled&stealthed.rogue&!set_bonus.tier21_2pc&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(talent.exsanguinate.enabled|target.time_to_die-remains>4)
    if S.Rupture:IsCastable("Melee") and Player:ComboPoints() > 0 and S.Nightstalker:IsAvailable() and not AC.Tier21_4Pc
      and (not I.MantleoftheMasterAssassin:IsEquipped() or not AC.Tier19_4Pc)
      and (S.Exsanguinate:IsAvailable()
        or ((Target:FilteredTimeToDie(">", 4, -Target:DebuffRemainsP(S.Rupture)) or Target:TimeToDieIsNotValid())
          and Rogue.CanDoTUnit(Target, RuptureDMGThreshold))) then
      if AR.Cast(S.Rupture) then return "Cast"; end
    end
    -- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&set_bonus.tier20_4pc&((dot.garrote.remains<=13&!debuff.toxic_blade.up)|pmultiplier<=1)&!exsanguinated
    if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() and Player:ComboPointsDeficit() >= 1 and AC.Tier20_4Pc then
      if Target:IsInRange("Melee") and not AC.Exsanguinated(Target, "Garrote")
        and (Target:DebuffRemainsP(S.Garrote) <= 13 and not Target:Debuff(S.ToxicBladeDebuff) or Target:PMultiplier(S.Garrote) <= 1)
        and Rogue.CanDoTUnit(Target, GarroteDMGThreshold) then
        if AR.Cast(S.Garrote) then return "Cast"; end
      end
    end
    -- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&!set_bonus.tier20_4pc&refreshable&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>2
    if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() and Player:ComboPointsDeficit() >= 1 and not AC.Tier20_4Pc then
      if Target:IsInRange("Melee") and Target:DebuffRefreshableP(S.Garrote, 5.4) and (not AC.Exsanguinated(Target, "Garrote") or Target:DebuffRemainsP(S.Garrote) <= ExsanguinatedBleedTickTime*2)
        and (Target:FilteredTimeToDie(">", 2, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid())
        and Rogue.CanDoTUnit(Target, GarroteDMGThreshold) then
        if AR.Cast(S.Garrote) then return "Cast"; end
      end
      if AR.AoEON() then
        local BestUnit, BestUnitTTD = nil, 2;
        for _, Unit in pairs(Cache.Enemies["Melee"]) do
          if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemainsP(S.Garrote))
            and Rogue.CanDoTUnit(Unit, GarroteDMGThreshold)
            and Unit:DebuffRefreshableP(S.Garrote, 5.4) and (not AC.Exsanguinated(Unit, "Garrote") or Unit:DebuffRemainsP(S.Garrote) <= ExsanguinatedBleedTickTime*2) then
              BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
          end
        end
        if BestUnit then
          AR.CastLeftNameplate(BestUnit, S.Garrote);
        end
      end
    end
    -- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&!set_bonus.tier20_4pc&remains<=10&pmultiplier<=1&!exsanguinated&target.time_to_die-remains>2
    if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() and Player:ComboPointsDeficit() >= 1 and not AC.Tier20_4Pc then
      if Target:IsInRange("Melee") and Target:DebuffRemainsP(S.Garrote) <= 10 and Target:PMultiplier(S.Garrote) <= 1 and not AC.Exsanguinated(Target, "Garrote")
        and (Target:FilteredTimeToDie(">", 2, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid())
        and Rogue.CanDoTUnit(Target, GarroteDMGThreshold) then
        if AR.Cast(S.Garrote) then return "Cast"; end
      end
      if AR.AoEON() then
        local BestUnit, BestUnitTTD = nil, 2;
        for _, Unit in pairs(Cache.Enemies["Melee"]) do
          if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemainsP(S.Garrote))
            and Rogue.CanDoTUnit(Unit, GarroteDMGThreshold)
            and Unit:DebuffRemainsP(S.Garrote) <= 10 and Unit:PMultiplier(S.Garrote) <= 1 and not AC.Exsanguinated(Unit, "Garrote") then
              BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
          end
        end
        if BestUnit then
          AR.CastLeftNameplate(BestUnit, S.Garrote);
        end
      end
    end
  end
  -- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&combo_points>=3&!ticking&mantle_duration<=0.2&target.time_to_die>6
  if S.Rupture:IsCastable("Melee") and not S.Exsanguinate:IsAvailable() and Player:ComboPoints() >= 3
    and not Target:Debuff(S.Rupture) and Rogue.MantleDuration() <= 0.2
    and (Target:FilteredTimeToDie(">", 6) or Target:TimeToDieIsNotValid())
    and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
    if AR.Cast(S.Rupture) then return "Cast"; end
  end
  -- actions.maintain+=/rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
  -- TODO: Test 4-5 cp rupture for Exsg
  if AR.CDsON() and S.Rupture:IsCastable("Melee") and Player:ComboPoints() > 0 and S.Exsanguinate:IsAvailable()
    and ((Player:ComboPoints() >= Rogue.CPMaxSpend() and S.Exsanguinate:CooldownRemainsP() < 1)
      or (not Target:Debuff(S.Rupture) and (AC.CombatTime() > 10 or (Player:ComboPoints() >= 2+(S.UrgetoKill:ArtifactEnabled() and 1 or 0))))) then
    if AR.Cast(S.Rupture) then return "Cast"; end
  end
  -- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>6
  if Player:ComboPoints() >= 4 then
    if Target:IsInRange("Melee") and Target:DebuffRefreshableP(S.Rupture, RuptureThreshold)
      and (Target:PMultiplier(S.Rupture) <= 1 or Target:DebuffRemainsP(S.Rupture) <= (AC.Exsanguinated(Target, "Rupture") and ExsanguinatedBleedTickTime or BleedTickTime))
      and (not AC.Exsanguinated(Target, "Rupture") or Target:DebuffRemainsP(S.Rupture) <= ExsanguinatedBleedTickTime*2)
      and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemainsP(S.Rupture)) or Target:TimeToDieIsNotValid())
      and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
      if AR.Cast(S.Rupture) then return "Cast"; end
    end
    if AR.AoEON() then
      local BestUnit, BestUnitTTD = nil, 6;
      for _, Unit in pairs(Cache.Enemies["Melee"]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemainsP(S.Rupture))
          and Rogue.CanDoTUnit(Unit, RuptureDMGThreshold)
          and Unit:DebuffRefreshableP(S.Rupture, RuptureThreshold)
          and (Unit:PMultiplier(S.Rupture) <= 1 or Unit:DebuffRemainsP(S.Rupture) <= (AC.Exsanguinated(Unit, "Rupture") and ExsanguinatedBleedTickTime or BleedTickTime))
          and (not AC.Exsanguinated(Unit, "Rupture") or Unit:DebuffRemainsP(S.Rupture) <= ExsanguinatedBleedTickTime*2) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Rupture);
      end
    end
  end
  -- actions.maintain+=/call_action_list,name=kb,if=combo_points.deficit>=1+(mantle_duration>=0.2)&(!talent.exsanguinate.enabled|!cooldown.exanguinate.up|time>9)
  if AR.CDsON() and S.Kingsbane:IsCastable("Melee") and Player:ComboPointsDeficit() >= 1 + (Rogue.MantleDuration() > 0.2 and 1 or 0)
    and (not S.Exsanguinate:IsAvailable() or not S.Exsanguinate:CooldownUp() or AC.CombatTime() > 9) then
    ShouldReturn2 = Kingsbane();
    if ShouldReturn2 then return ShouldReturn2; end
  end
  -- actions.maintain+=/garrote,cycle_targets=1,if=(!talent.subterfuge.enabled|!(cooldown.vanish.up&cooldown.vendetta.remains<=4))&combo_points.deficit>=1&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
  if S.Garrote:IsCastable() and (not S.Subterfuge:IsAvailable() or not AR.CDsON() or not (S.Vanish:CooldownUp() and S.Vendetta:CooldownRemainsP() <= 4)) and Player:ComboPointsDeficit() >= 1 then
    if Target:IsInRange("Melee") and Target:DebuffRefreshableP(S.Garrote, 5.4)
      and (Target:PMultiplier(S.Garrote) <= 1 or Target:DebuffRemainsP(S.Garrote) <= (AC.Exsanguinated(Target, "Garrote") and ExsanguinatedBleedTickTime or BleedTickTime))
      and (not AC.Exsanguinated(Target, "Garrote") or Target:DebuffRemainsP(S.Garrote) <= 1.5)
      and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid())
      and Rogue.CanDoTUnit(Target, GarroteDMGThreshold) then
      -- actions.maintain+=/pool_resource,for_next=1
      if Player:EnergyPredicted() < 45 then
        if AR.Cast(S.PoolEnergy) then return "Pool for Garrote (ST)"; end
      end
      if AR.Cast(S.Garrote) then return "Cast"; end
    end
    if AR.AoEON() then
      local BestUnit, BestUnitTTD = nil, 4;
      for _, Unit in pairs(Cache.Enemies["Melee"]) do
        if Everyone.UnitIsCycleValid(Unit, BestUnitTTD, -Unit:DebuffRemainsP(S.Garrote))
          and Rogue.CanDoTUnit(Unit, GarroteDMGThreshold)
          and Unit:DebuffRefreshableP(S.Garrote, 5.4)
          and (Unit:PMultiplier(S.Garrote) <= 1 or Unit:DebuffRemainsP(S.Garrote) <= (AC.Exsanguinated(Unit, "Garrote") and ExsanguinatedBleedTickTime or BleedTickTime))
          and (not AC.Exsanguinated(Unit, "Garrote") or Unit:DebuffRemainsP(S.Garrote) <= 1.5) then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        -- actions.maintain+=/pool_resource,for_next=1
        if Player:EnergyPredicted() < 45 then
          if AR.Cast(S.PoolEnergy) then return "Pool for Garrote (Cycle)"; end
        end
        AR.CastLeftNameplate(BestUnit, S.Garrote);
      end
    end
  end
  -- actions.maintain+=/garrote,if=set_bonus.tier20_4pc&talent.exsanguinate.enabled&prev_gcd.1.rupture&cooldown.exsanguinate.remains<1&(!cooldown.vanish.up|time>12)
  if S.Garrote:IsCastable("Melee") and AC.Tier20_4Pc and S.Exsanguinate:IsAvailable() and Player:PrevGCD(1, S.Rupture)
    and S.Exsanguinate:CooldownRemainsP() < 1 and (not S.Vanish:CooldownUp() or AC.CombatTime() > 12) then
    if AR.Cast(S.Garrote) then return "Cast"; end
  end
  return false;
end
local MythicDungeon;
do
  local SappedSoulSpells = {
    {S.Kick, "Cast Kick (Sappel Soul)", function () return IsInMeleeRange; end},
    {S.Feint, "Cast Feint (Sappel Soul)", function () return true; end},
    {S.CrimsonVial, "Cast Crimson Vial (Sappel Soul)", function () return true; end}
  };
  MythicDungeon = function ()
    -- Sapped Soul
    if AC.MythicDungeon() == "Sapped Soul" then
      for i = 1, #SappedSoulSpells do
        local Spell = SappedSoulSpells[i];
        if Spell[1]:IsCastable() and Spell[3]() then
          AR.ChangePulseTimer(1);
          AR.Cast(Spell[1]);
          return Spell[2];
        end
      end
    end
    return false;
  end
end
local function TrainingScenario ()
  if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*Player:ComboPoints() then
    -- Kidney Shot
    if S.KidneyShot:IsCastable("Melee") and Player:ComboPoints() > 0 then
      if AR.Cast(S.KidneyShot) then return "Cast Kidney Shot (Unstable Explosion)"; end
    end
  end
  return false;
end
local Interrupts = {
  {S.Blind, "Cast Blind (Interrupt)", function () return true; end},
  {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return Player:ComboPoints() > 0; end}
}

-- APL Main
local function APL ()
  -- Spell ID Changes check
  Stealth = S.Subterfuge:IsAvailable() and S.Stealth2 or S.Stealth; -- w/ or w/o Subterfuge Talent
  -- Unit Update
  AC.GetEnemies(30); -- Used for Poisoned Knife Poison refresh
  AC.GetEnemies(10, true); -- Fan of Knives & Death from Above
  AC.GetEnemies("Melee"); -- Melee
  Everyone.AoEToggleEnemiesUpdate();
  -- Compute Cache
  RuptureThreshold = (4 + Player:ComboPoints() * 4) * 0.3;
  RuptureDMGThreshold = S.Envenom:Damage()*Settings.Assassination.EnvenomDMGOffset; -- Used to check if Rupture is worth to be casted since it's a finisher.
  GarroteDMGThreshold = S.Mutilate:Damage()*Settings.Assassination.MutilateDMGOffset; -- Used as TTD Not Valid fallback since it's a generator.
  -- Defensives
    -- Crimson Vial
    ShouldReturn = Rogue.CrimsonVial(S.CrimsonVial);
    if ShouldReturn then return ShouldReturn; end
    -- Feint
    ShouldReturn = Rogue.Feint(S.Feint);
    if ShouldReturn then return ShouldReturn; end
  -- Poisons
    -- Lethal Poison
    if Player:BuffRemainsP(S.DeadlyPoison) < Settings.Assassination.PoisonRefresh*60
      and Player:BuffRemainsP(S.WoundPoison) < Settings.Assassination.PoisonRefresh*60 then
      AR.CastSuggested(S.DeadlyPoison);
    end
    -- Non-Lethal Poison
    if Player:BuffRemainsP(S.CripplingPoison) < Settings.Assassination.PoisonRefresh*60
      and Player:BuffRemainsP(S.LeechingPoison) < Settings.Assassination.PoisonRefresh*60 then
      if S.LeechingPoison:IsAvailable() then
        AR.CastSuggested(S.LeechingPoison);
      else
        AR.CastSuggested(S.CripplingPoison);
      end
    end
  -- Out of Combat
    if not Player:AffectingCombat() then
      -- Stealth
      ShouldReturn = Rogue.Stealth(Stealth);
      if ShouldReturn then return ShouldReturn; end
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if Everyone.TargetIsValid() and Target:IsInRange("Melee") then
        if Player:ComboPoints() >= 5 then
          if S.Rupture:IsCastable() and not Target:Debuff(S.Rupture)
            and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
            if AR.Cast(S.Rupture) then return "Cast"; end
          elseif S.Envenom:IsCastable() then
            if AR.Cast(S.Envenom) then return "Cast"; end
          end
        elseif S.Garrote:IsCastable() and not Target:Debuff(S.Garrote) and Rogue.CanDoTUnit(Target, GarroteDMGThreshold) then
          if AR.Cast(S.Garrote) then return "Cast"; end
        elseif S.FanofKnives:IsCastable()
          and (Cache.EnemiesCount[10] >= 2 + (I.InsigniaofRavenholdt:IsEquipped() and 1 or 0) or (AR.AoEON() and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
          if AR.Cast(S.FanofKnives) then return "Cast"; end
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
      Everyone.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, Interrupts);
      -- actions=variable,name=energy_regen_combined,value=energy.regen+poisoned_bleeds*(7+talent.venom_rush.enabled*3)%2
      Energy_Regen_Combined = Player:EnergyRegen() + Rogue.PoisonedBleeds() * (7 + (S.VenomRush:IsAvailable() and 3 or 0)) / 2;
      -- actions+=/variable,name=energy_time_to_max_combined,value=energy.deficit%variable.energy_regen_combined
      Energy_Time_To_Max_Combined = Player:EnergyDeficit() / Energy_Regen_Combined;
      -- actions+=/call_action_list,name=cds
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
      -- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)&(!dot.rupture.refreshable|(dot.rupture.exsanguinated&dot.rupture.remains>=3.5)|target.time_to_die-dot.rupture.remains<=6)&active_dot.rupture>=spell_targets.rupture
      if (not AR.CDsON() or not S.Exsanguinate:IsAvailable() or S.Exsanguinate:CooldownRemainsP() > 2)
        and (not Target:DebuffRefreshableP(S.Rupture, RuptureThreshold) or (AC.Exsanguinated(Target, "Rupture") and Target:DebuffRemainsP(S.Rupture) >= 3.5)
          or Target:FilteredTimeToDie("<=", 6, -Target:DebuffRemainsP(S.Rupture))
          or Target:TimeToDieIsNotValid()
          or not Rogue.CanDoTUnit(Target, RuptureDMGThreshold)) then
        ShouldReturn = Finish();
        if ShouldReturn then return ShouldReturn; end
      end
      -- actions+=/call_action_list,name=build,if=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined
      if Player:ComboPointsDeficit() > 1 or Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined then
        ShouldReturn = Build();
        if ShouldReturn then return ShouldReturn; end
      end
      -- Poisoned Knife Out of Range [EnergyCap] or [PoisonRefresh]
      if S.PoisonedKnife:IsCastable(30) and not Player:IsStealthed(true, true)
        and ((not Target:IsInRange(10) and Player:EnergyTimeToMax() <= Player:GCD()*1.2)
          or (not Target:IsInRange("Melee") and Target:DebuffRefreshableP(S.DeadlyPoisonDebuff, 4))) then
        if AR.Cast(S.PoisonedKnife) then return "Cast Poisoned Knife"; end
      end
      -- Trick to take in consideration the Recovery Setting
      if S.Mutilate:IsCastable("Melee") then
        if AR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
      end
    end
end

AR.SetAPL(259, APL);

-- Last Update: 12/15/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/apply_poison
-- actions.precombat+=/stealth
-- actions.precombat+=/potion
-- actions.precombat+=/marked_for_death,if=raid_event.adds.in>40

-- # Executed every time the actor is available.
-- actions=variable,name=energy_regen_combined,value=energy.regen+poisoned_bleeds*(7+talent.venom_rush.enabled*3)%2
-- actions+=/variable,name=energy_time_to_max_combined,value=energy.deficit%variable.energy_regen_combined
-- actions+=/call_action_list,name=cds
-- actions+=/call_action_list,name=maintain
-- # The 'active_dot.rupture>=spell_targets.rupture' means that we don't want to envenom as long as we can multi-rupture (i.e. units that don't have rupture yet).
-- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)&(!dot.rupture.refreshable|(dot.rupture.exsanguinated&dot.rupture.remains>=3.5)|target.time_to_die-dot.rupture.remains<=6)&active_dot.rupture>=spell_targets.rupture
-- actions+=/call_action_list,name=build,if=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined

-- # Builders
-- actions.build=hemorrhage,if=refreshable
-- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+equipped.insignia_of_ravenholdt
-- actions.build+=/fan_of_knives,if=spell_targets>=2+equipped.insignia_of_ravenholdt|buff.the_dreadlords_deceit.stack>=29
-- actions.build+=/mutilate,cycle_targets=1,if=dot.deadly_poison_dot.refreshable
-- actions.build+=/mutilate

-- # Cooldowns
-- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|debuff.vendetta.up&cooldown.vanish.remains<5
-- actions.cds+=/use_item,name=draught_of_souls,if=energy.deficit>=35+variable.energy_regen_combined*2&(!equipped.mantle_of_the_master_assassin|cooldown.vanish.remains>8)
-- actions.cds+=/use_item,name=draught_of_souls,if=mantle_duration>0&mantle_duration<3.5&dot.kingsbane.ticking
-- actions.cds+=/use_item,name=specter_of_betrayal,if=buff.bloodlust.react|target.time_to_die<=20|debuff.vendetta.up
-- actions.cds+=/blood_fury,if=debuff.vendetta.up
-- actions.cds+=/berserking,if=debuff.vendetta.up
-- actions.cds+=/arcane_torrent,if=dot.kingsbane.ticking&!buff.envenom.up&energy.deficit>=15+variable.energy_regen_combined*gcd.remains*1.1
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
-- actions.cds+=/vendetta,if=!talent.exsanguinate.enabled|dot.rupture.ticking
-- actions.cds+=/exsanguinate,if=!set_bonus.tier20_4pc&(prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend&!stealthed.rogue|dot.garrote.pmultiplier>1&!cooldown.vanish.up&buff.subterfuge.up)
-- actions.cds+=/exsanguinate,if=set_bonus.tier20_4pc&dot.garrote.remains>20&dot.rupture.remains>4+4*cp_max_spend
-- # Nightstalker w/o Exsanguinate: Vanish Envenom if Mantle & T19_4PC, else Vanish Rupture
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&!talent.exsanguinate.enabled&mantle_duration=0&((equipped.mantle_of_the_master_assassin&set_bonus.tier19_4pc)|((!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(dot.rupture.refreshable|debuff.vendetta.up)))
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&combo_points>=cp_max_spend&talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&(dot.rupture.ticking|time>10)
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&equipped.mantle_of_the_master_assassin&(debuff.vendetta.up|target.time_to_die<10)&mantle_duration=0
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&!equipped.mantle_of_the_master_assassin&!stealthed.rogue&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
-- actions.cds+=/vanish,if=talent.shadow_focus.enabled&variable.energy_time_to_max_combined>=2&combo_points.deficit>=4
-- actions.cds+=/toxic_blade,if=combo_points.deficit>=1+(mantle_duration>=0.2)&dot.rupture.remains>8&cooldown.vendetta.remains>10

-- # Finishers
-- actions.finish=death_from_above,if=combo_points>=5
-- actions.finish+=/envenom,if=combo_points>=4+(talent.deeper_stratagem.enabled&!set_bonus.tier19_4pc)&(debuff.vendetta.up|mantle_duration>=0.2|debuff.surge_of_toxins.remains<0.2|energy.deficit<=25+variable.energy_regen_combined)
-- actions.finish+=/envenom,if=talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<0.2

-- # Kingsbane
-- # Sinister Circulation makes it worth to cast Kingsbane on CD except if you're [stealthed w/ Nighstalker and have Mantle & T19_4PC to Envenom] or before vendetta if you have mantle during the opener.
-- actions.kb=kingsbane,if=artifact.sinister_circulation.enabled&!(equipped.duskwalkers_footpads&equipped.convergence_of_fates&artifact.master_assassin.rank>=6)&(time>25|!equipped.mantle_of_the_master_assassin|(debuff.vendetta.up&debuff.surge_of_toxins.up))&(talent.subterfuge.enabled|!stealthed.rogue|(talent.nightstalker.enabled&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)))
-- actions.kb+=/kingsbane,if=buff.envenom.up&((debuff.vendetta.up&debuff.surge_of_toxins.up)|cooldown.vendetta.remains<=5.8|cooldown.vendetta.remains>=10)

-- # Maintain
-- actions.maintain=rupture,if=talent.nightstalker.enabled&stealthed.rogue&!set_bonus.tier21_2pc&(!equipped.mantle_of_the_master_assassin|!set_bonus.tier19_4pc)&(talent.exsanguinate.enabled|target.time_to_die-remains>4)
-- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&set_bonus.tier20_4pc&((dot.garrote.remains<=13&!debuff.toxic_blade.up)|pmultiplier<=1)&!exsanguinated
-- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&!set_bonus.tier20_4pc&refreshable&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>2
-- actions.maintain+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&stealthed.rogue&combo_points.deficit>=1&!set_bonus.tier20_4pc&remains<=10&pmultiplier<=1&!exsanguinated&target.time_to_die-remains>2
-- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&combo_points>=3&!ticking&mantle_duration<=0.2&target.time_to_die>6
-- actions.maintain+=/rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
-- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>6
-- actions.maintain+=/call_action_list,name=kb,if=combo_points.deficit>=1+(mantle_duration>=0.2)&(!talent.exsanguinate.enabled|!cooldown.exanguinate.up|time>9)
-- actions.maintain+=/pool_resource,for_next=1
-- actions.maintain+=/garrote,cycle_targets=1,if=(!talent.subterfuge.enabled|!(cooldown.vanish.up&cooldown.vendetta.remains<=4))&combo_points.deficit>=1&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
-- actions.maintain+=/garrote,if=set_bonus.tier20_4pc&talent.exsanguinate.enabled&prev_gcd.1.rupture&cooldown.exsanguinate.remains<1&(!cooldown.vanish.up|time>12)
