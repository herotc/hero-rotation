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
  VanishBuff            = Spell(11327),
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
  PoisonKnives          = Spell(192376),
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
  PickPocket            = Spell(921),
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
  VirulentPoisons       = Spell(252277),
  -- Misc
  PoolEnergy            = Spell(9999000010)
};
local S = Spell.Rogue.Assassination;
-- Items
if not Item.Rogue then Item.Rogue = {}; end
Item.Rogue.Assassination = {
  -- Legendaries
  DuskwalkersFootpads           = Item(137030, {8}),
  InsigniaofRavenholdt          = Item(137049, {11, 12}),
  MantleoftheMasterAssassin     = Item(144236, {3}),
  ZoldyckFamilyTrainingShackles = Item(137098, {9}),
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
      (Target:DebuffP(S.ToxicBladeDebuff) and 1.35 or 1) *
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

-- Handle CastLeftNameplate Suggestions for DoT Spells
local function SuggestCycleDoT(DoTSpell, DoTEvaluation, DoTMinTTD)
  -- Prefer melee cycle units
  local BestUnit, BestUnitTTD = Target, DoTMinTTD;
  for _, CycleUnit in pairs(Cache.Enemies["Melee"]) do
    if Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemainsP(DoTSpell)) and DoTEvaluation(CycleUnit) then
      BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie();
    end
  end
  if BestUnit then
    if BestUnit:GUID() == Target:GUID() then return; end;
    AR.CastLeftNameplate(BestUnit, DoTSpell);
  -- Check ranged units next, if the RangedMultiDoT option is enabled
  elseif Settings.Assassination.RangedMultiDoT then
    BestUnit, BestUnitTTD = Target, DoTMinTTD;
    for _, CycleUnit in pairs(Cache.Enemies[10]) do
      if Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemainsP(DoTSpell)) and DoTEvaluation(CycleUnit) then
        BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie();
      end
    end
    if BestUnit then
      if BestUnit:GUID() == Target:GUID() then return; end;
      AR.CastLeftNameplate(BestUnit, DoTSpell);
    end
  end
end

-- Melee Is In Range w/ DfA Handler
local function IsInMeleeRange ()
  return (Target:IsInRange("Melee") or S.DeathfromAbove:TimeSinceLastCast() <= 1.5) and true or false;
end

local MythicDungeon;
do
  local SappedSoulSpells = {
    {S.Kick, "Cast Kick (Sapped Soul)", function () return IsInMeleeRange(); end},
    {S.Feint, "Cast Feint (Sapped Soul)", function () return true; end},
    {S.CrimsonVial, "Cast Crimson Vial (Sapped Soul)", function () return true; end}
  };
  MythicDungeon = function ()
    -- Sapped Soul
    if AC.MythicDungeon() == "Sapped Soul" then
      for i = 1, #SappedSoulSpells do
        local SappedSoulSpell = SappedSoulSpells[i];
        if SappedSoulSpell[1]:IsCastable() and SappedSoulSpell[3]() then
          AR.ChangePulseTimer(1);
          AR.Cast(SappedSoulSpell[1]);
          return SappedSoulSpell[2];
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

-- APL Action Lists (and Variables)
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
        if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury"; end
      end
      -- actions.cds+=/berserking,if=debuff.vendetta.up
      if S.Berserking:IsCastable() then
        if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking"; end
      end
      -- actions.cds+=/arcane_torrent,if=dot.kingsbane.ticking&!buff.envenom.up&energy.deficit>=15+variable.energy_regen_combined*gcd.remains*1.1
      -- Note: Temporarly modified the conditions
      if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficitPredicted() > 15 + Energy_Regen_Combined * Player:GCDRemains() * 1.1 then
        if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Arcane Torrent"; end
      end
    end

    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
    if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
      AR.CastSuggested(S.MarkedforDeath);
    end
    -- actions.cds+=/vendetta,if=!talent.exsanguinate.enabled|dot.rupture.ticking
    if S.Vendetta:IsCastable() and (not S.Exsanguinate:IsAvailable() or Target:DebuffP(S.Rupture)) then
      if AR.Cast(S.Vendetta, Settings.Assassination.OffGCDasOffGCD.Vendetta) then return "Cast Vendetta"; end
    end
    if S.Exsanguinate:IsCastable() then
      if not AC.Tier20_4Pc then
        -- actions.cds+=/exsanguinate,if=!set_bonus.tier20_4pc&(prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend&!stealthed.rogue|dot.garrote.pmultiplier>1&!cooldown.vanish.up&buff.subterfuge.up)
        if Player:PrevGCD(1, S.Rupture) and Target:DebuffRemainsP(S.Rupture) > 4+4*Rogue.CPMaxSpend() and not Player:IsStealthed(true, false)
          or Target:PMultiplier(S.Garrote) > 1 and not S.Vanish:CooldownUp() and Player:BuffP(S.Subterfuge) then
          if AR.Cast(S.Exsanguinate) then return "Cast Exsanguinate"; end
        end
      else
        -- actions.cds+=/exsanguinate,if=set_bonus.tier20_4pc&dot.garrote.remains>20&dot.rupture.remains>4+4*cp_max_spend
        if Target:DebuffRemainsP(S.Garrote) > 20 and Target:DebuffRemainsP(S.Rupture) > 4+4*Rogue.CPMaxSpend() then
          if AR.Cast(S.Exsanguinate) then return "Cast Exsanguinate (T20 4pc)"; end
        end
      end
    end
    if S.Vanish:IsCastable() and not Player:IsTanking(Target) then
      if S.Nightstalker:IsAvailable() and Player:ComboPoints() >= Rogue.CPMaxSpend() then
        if not S.Exsanguinate:IsAvailable() then
          -- actions.cds+=/vanish,if=talent.nightstalker.enabled&!talent.exsanguinate.enabled&combo_points>=cp_max_spend&mantle_duration=0&debuff.vendetta.up
          if Rogue.MantleDuration() == 0 and Target:Debuff(S.Vendetta) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Nightstalker)"; end
          end
        else
          -- actions.cds+=/vanish,if=talent.nightstalker.enabled&talent.exsanguinate.enabled&combo_points>=cp_max_spend&mantle_duration=0&cooldown.exsanguinate.remains<1
          if Rogue.MantleDuration() == 0 and S.Exsanguinate:CooldownRemainsP() < 1 and (Target:Debuff(S.Rupture) or AC.CombatTime() > 10) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Nightstalker, Exsanguinate)"; end
          end
        end
      end
      if S.Subterfuge:IsAvailable() then
        if I.MantleoftheMasterAssassin:IsEquipped() then
          -- actions.cds+=/vanish,if=talent.subterfuge.enabled&equipped.mantle_of_the_master_assassin&(debuff.vendetta.up|target.time_to_die<10)&mantle_duration=0
          if (Target:Debuff(S.Vendetta) or Target:FilteredTimeToDie("<", 10)) and Rogue.MantleDuration() == 0 then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Subterfuge, Mantle)"; end
          end
        else
          -- actions.cds+=/vanish,if=talent.subterfuge.enabled&!equipped.mantle_of_the_master_assassin&!stealthed.rogue&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
          if not Player:IsStealthed(true, false) and Target:DebuffRefreshableP(S.Garrote, 5.4)
            and ((Cache.EnemiesCount[10] <= 3 and Player:ComboPointsDeficit() >= 1+Cache.EnemiesCount[10]) or (Cache.EnemiesCount[10] >= 4 and Player:ComboPointsDeficit() >= 4)) then
            if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Subterfuge)"; end
          end
        end
      end
      -- actions.cds+=/vanish,if=talent.shadow_focus.enabled&variable.energy_time_to_max_combined>=2&combo_points.deficit>=4
      if S.ShadowFocus:IsAvailable() and Energy_Time_To_Max_Combined >= 2 and Player:ComboPoints() >= 4 then
        if AR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Shadow Focus)"; end
      end
    end
    -- actions.cds+=/toxic_blade,if=combo_points.deficit>=1+(mantle_duration>=0.2)&dot.rupture.remains>8&cooldown.vendetta.remains>10
    if S.ToxicBlade:IsCastable("Melee") and Player:ComboPointsDeficit() >= 1 + (Rogue.MantleDuration() > 0.2 and 1 or 0)
      and Target:DebuffRemainsP(S.Rupture) > 8 and S.Vendetta:CooldownRemainsP() > 10 then
      if AR.Cast(S.ToxicBlade) then return "Cast Toxic Blade"; end
    end
    -- actions.cds+=/kingsbane,if=combo_points.deficit>=1+(mantle_duration>=0.2)&!stealthed.rogue&(!cooldown.toxic_blade.ready|!talent.toxic_blade.enabled&buff.envenom.up)
    if S.Kingsbane:IsCastable("Melee") and Player:ComboPointsDeficit() >= 1 + (Rogue.MantleDuration() > 0.2 and 1 or 0) and not Player:IsStealthed(true, false)
      and ((S.ToxicBlade:IsAvailable() and not S.ToxicBlade:CooldownUp()) or (not S.ToxicBlade:IsAvailable() and Player:BuffP(S.Envenom))) then
      if AR.Cast(S.Kingsbane) then return "Cast Kingsbane"; end
    end
  end
  return false;
end
-- # Stealthed
local function Stealthed ()
  -- actions.stealthed=mutilate,if=talent.shadow_focus.enabled&dot.garrote.ticking
  if S.Mutilate:IsCastable("Melee") and S.ShadowFocus:IsAvailable() and Target:DebuffP(S.Garrote) then
    if AR.Cast(S.Mutilate) then return "Cast Mutilate"; end
  end
  if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() and Player:ComboPointsDeficit() >= 1 then
    -- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&combo_points.deficit>=1&set_bonus.tier20_4pc&((dot.garrote.remains<=13&!debuff.toxic_blade.up)|pmultiplier<=1)&!exsanguinated
    if AC.Tier20_4Pc then
      local function Evaluate_Garrote_Target(TargetUnit)
        return not AC.Exsanguinated(TargetUnit, "Garrote")
          and (TargetUnit:DebuffRemainsP(S.Garrote) <= 13 and not TargetUnit:DebuffP(S.ToxicBladeDebuff) or TargetUnit:PMultiplier(S.Garrote) <= 1)
          and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold);
      end
      if Target:IsInRange("Melee") and Evaluate_Garrote_Target(Target) then
        if AR.Cast(S.Garrote) then return "Cast Garrote (Subterfuge, T20)"; end
      end
      if AR.AoEON() then
        SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target);
      end
    end
    -- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&combo_points.deficit>=1&!set_bonus.tier20_4pc&refreshable&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>2
    if not AC.Tier20_4Pc then
      local function Evaluate_Garrote_Target(TargetUnit)
        return TargetUnit:DebuffRefreshableP(S.Garrote, 5.4)
          and (not AC.Exsanguinated(TargetUnit, "Garrote") or TargetUnit:DebuffRemainsP(S.Garrote) <= ExsanguinatedBleedTickTime*2)
          and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold);
      end
      if Target:IsInRange("Melee") and Evaluate_Garrote_Target(Target)
        and (Target:FilteredTimeToDie(">", 2, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid()) then
        if AR.Cast(S.Garrote) then return "Cast Garrote (Subterfuge, Refresh)"; end
      end
      if AR.AoEON() then
        SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target, 2);
      end
    end
    -- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&combo_points.deficit>=1&!set_bonus.tier20_4pc&remains<=10&pmultiplier<=1&!exsanguinated&target.time_to_die-remains>2
    if not AC.Tier20_4Pc then
      local function Evaluate_Garrote_Target(TargetUnit)
        return TargetUnit:DebuffRemainsP(S.Garrote) <= 10 and TargetUnit:PMultiplier(S.Garrote) <= 1 and not AC.Exsanguinated(TargetUnit, "Garrote")
          and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold);
      end
      if Target:IsInRange("Melee") and Evaluate_Garrote_Target(Target)
        and (Target:FilteredTimeToDie(">", 2, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid()) then
        if AR.Cast(S.Garrote) then return "Cast Garrote (Subterfuge)"; end
      end
      if AR.AoEON() then
        SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target, 2);
      end
    end
  end
  -- actions.stealthed+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>6
  if Player:ComboPoints() >= 4 then
    local function Evaluate_Rupture_Target(TargetUnit)
      return TargetUnit:DebuffRefreshableP(S.Rupture, RuptureThreshold)
        and (TargetUnit:PMultiplier(S.Rupture) <= 1 or TargetUnit:DebuffRemainsP(S.Rupture) <= (AC.Exsanguinated(TargetUnit, "Rupture") and ExsanguinatedBleedTickTime or BleedTickTime))
        and (not AC.Exsanguinated(TargetUnit, "Rupture") or TargetUnit:DebuffRemainsP(S.Rupture) <= ExsanguinatedBleedTickTime*2)
        and Rogue.CanDoTUnit(TargetUnit, RuptureDMGThreshold);
    end
    if Target:IsInRange("Melee") and Evaluate_Rupture_Target(Target)
      and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemainsP(S.Rupture)) or Target:TimeToDieIsNotValid()) then
      if AR.Cast(S.Rupture) then return "Cast Rupture (Refresh)"; end
    end
    if AR.AoEON() then
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, 6);
    end
  end
  -- actions.stealthed+=/rupture,if=talent.exsanguinate.enabled&talent.nightstalker.enabled&target.time_to_die-remains>6
  if S.Rupture:IsCastable("Melee") and Player:ComboPoints() > 0 and S.Exsanguinate:IsAvailable() and S.Nightstalker:IsAvailable()
    and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemainsP(S.Rupture)) or Target:TimeToDieIsNotValid()) then
    if AR.Cast(S.Rupture) then return "Cast Rupture (Exsanguinate)"; end
  end
  -- actions.stealthed+=/envenom,if=combo_points>=cp_max_spend
  if S.Envenom:IsCastable("Melee") and Player:ComboPoints() >= Rogue.CPMaxSpend() then
    if AR.Cast(S.Envenom) then return "Cast Envenom"; end
  end
  -- actions.stealthed+=/garrote,if=!talent.subterfuge.enabled&target.time_to_die-remains>4
  if S.Garrote:IsCastable("Melee") and not S.Subterfuge:IsAvailable()
    and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid()) then
    if AR.Cast(S.Garrote) then return "Cast Garrote"; end
  end
  -- actions.stealthed+=/mutilate
  if S.Mutilate:IsCastable("Melee") then
    if AR.Cast(S.Mutilate) then return "Cast Mutilate"; end
  end
end
-- # AoE
local function AoE ()
  -- actions.aoe=/envenom,if=!buff.envenom.up&combo_points>=cp_max_spend
  if S.Envenom:IsCastable("Melee") and not Player:BuffP(S.Envenom) and Player:ComboPoints() >= Rogue.CPMaxSpend() then
    if AR.Cast(S.Envenom) then return "Cast Envenom (AoE Buff)"; end
  end
  -- actions.aoe+=/rupture,cycle_targets=1,if=combo_points>=cp_max_spend&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
  if Player:ComboPoints() >= Rogue.CPMaxSpend() then
    local function Evaluate_Rupture_Target(TargetUnit)
      return TargetUnit:DebuffRefreshableP(S.Rupture, RuptureThreshold)
        and Rogue.CanDoTUnit(TargetUnit, RuptureDMGThreshold)
        and (TargetUnit:PMultiplier(S.Rupture) <= 1 or TargetUnit:DebuffRemainsP(S.Rupture) <= (AC.Exsanguinated(TargetUnit, "Rupture") and ExsanguinatedBleedTickTime or BleedTickTime))
        and (not AC.Exsanguinated(TargetUnit, "Rupture") or TargetUnit:DebuffRemainsP(S.Rupture) <= ExsanguinatedBleedTickTime*2)
    end
    if Target:IsInRange("Melee") and Evaluate_Rupture_Target(Target)
      and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemainsP(S.Rupture)) or Target:TimeToDieIsNotValid()) then
      if AR.Cast(S.Rupture) then return "Cast Rupture (AoE)"; end
    end
    SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, 4);
  end
  -- actions.aoe+=/envenom,if=combo_points>=cp_max_spend
  if S.Envenom:IsCastable("Melee") and Player:ComboPoints() >= Rogue.CPMaxSpend() then
    if AR.Cast(S.Envenom) then return "Cast Envenom (AoE)"; end
  end
  -- actions.aoe+=/fan_of_knives
  if S.FanofKnives:IsCastable() then
    if AR.Cast(S.FanofKnives) then return "Cast Fan of Knives (AoE)"; end
  end
end
-- # Finishers
local function Finish ()
  -- actions.finish=death_from_above,if=combo_points>=5
  if S.DeathfromAbove:IsCastable(15) and Player:ComboPoints() >= 5 then
    if AR.Cast(S.DeathfromAbove) then return "Cast Death from Above"; end
  end
  if S.Envenom:IsCastable("Melee") then
    if S.Anticipation:IsAvailable() then
      -- actions.finish+=/envenom,if=talent.anticipation.enabled&combo_points>=5&((debuff.toxic_blade.up&buff.virulent_poisons.remains<2)|mantle_duration>=0.2|buff.virulent_poisons.remains<0.2|energy.deficit<=25+variable.energy_regen_combined)
      if Player:ComboPoints() >= 5 and ((Target:DebuffP(S.ToxicBladeDebuff) and Target:DebuffRemainsP(S.VirulentPoisons) < 2) or Rogue.MantleDuration() >= 0.2
        or Target:DebuffRemainsP(S.VirulentPoisons) < 0.2 or Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined) then
        if AR.Cast(S.Envenom) then return "Cast Envenom (Anticipation)"; end
      end
      -- actions.finish+=/envenom,if=talent.anticipation.enabled&combo_points>=4&!buff.virulent_poisons.up
      if Player:ComboPoints() >= 4 and not Target:DebuffP(S.VirulentPoisons) then
        if AR.Cast(S.Envenom) then return "Cast Envenom (Anticipation, T21 Refresh)"; end
      end
    else
      -- actions.finish+=/envenom,if=!talent.anticipation.enabled&combo_points>=4+(talent.deeper_stratagem.enabled&!set_bonus.tier19_4pc)&(debuff.vendetta.up|debuff.toxic_blade.up|mantle_duration>=0.2|debuff.surge_of_toxins.remains<0.2|energy.deficit<=25+variable.energy_regen_combined)
      if Player:ComboPoints() >= 4 + (S.DeeperStratagem:IsAvailable() and not AC.Tier19_4Pc and 1 or 0) and (Target:DebuffP(S.Vendetta)
        or Rogue.MantleDuration() >= 0.2 or Target:DebuffRemainsP(S.SurgeofToxins) < 0.2 or Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined) then
        if AR.Cast(S.Envenom) then return "Cast Envenom"; end
      end
    end
    -- actions.finish+=/envenom,if=talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<0.2
    if S.ElaboratePlanning:IsAvailable() and Player:ComboPoints() >= 3+(S.Exsanguinate:IsAvailable() and 0 or 1) and Player:BuffRemainsP(S.ElaboratePlanningBuff) < 0.2 then
      if AR.Cast(S.Envenom) then return "Cast Envenom (Elaborate Planning)"; end
    end
  end
  return false;
end
-- # Maintain
local function Maintain ()
  -- actions.maintain=rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
  if AR.CDsON() and S.Rupture:IsCastable("Melee") and Player:ComboPoints() > 0 and S.Exsanguinate:IsAvailable()
    and ((Player:ComboPoints() >= Rogue.CPMaxSpend() and S.Exsanguinate:CooldownRemainsP() < 1)
      or (not Target:DebuffP(S.Rupture) and (AC.CombatTime() > 10 or (Player:ComboPoints() >= 2+(S.UrgetoKill:ArtifactEnabled() and 1 or 0))))) then
    if AR.Cast(S.Rupture) then return "Cast Rupture (Exsanguinate)"; end
  end
  -- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>6
  if Player:ComboPoints() >= 4 then
    local function Evaluate_Rupture_Target(TargetUnit)
      return TargetUnit:DebuffRefreshableP(S.Rupture, RuptureThreshold)
        and (TargetUnit:PMultiplier(S.Rupture) <= 1 or TargetUnit:DebuffRemainsP(S.Rupture) <= (AC.Exsanguinated(TargetUnit, "Rupture") and ExsanguinatedBleedTickTime or BleedTickTime))
        and (not AC.Exsanguinated(TargetUnit, "Rupture") or TargetUnit:DebuffRemainsP(S.Rupture) <= ExsanguinatedBleedTickTime*2)
        and Rogue.CanDoTUnit(TargetUnit, RuptureDMGThreshold);
    end
    if Target:IsInRange("Melee") and Evaluate_Rupture_Target(Target)
      and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemainsP(S.Rupture)) or Target:TimeToDieIsNotValid()) then
      if AR.Cast(S.Rupture) then return "Cast Rupture (Refresh)"; end
    end
    if AR.AoEON() then
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, 6);
    end
  end
  -- actions.maintain+=/garrote,cycle_targets=1,if=(!talent.subterfuge.enabled|!(cooldown.vanish.up&cooldown.vendetta.remains<=4))&combo_points.deficit>=1&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
  if S.Garrote:IsCastable() and (not S.Subterfuge:IsAvailable() or not AR.CDsON() or not (S.Vanish:CooldownUp() and S.Vendetta:CooldownRemainsP() <= 4)) and Player:ComboPointsDeficit() >= 1 then
    local function Evaluate_Garrote_Target(TargetUnit)
      return TargetUnit:DebuffRefreshableP(S.Garrote, 5.4)
        and (TargetUnit:PMultiplier(S.Garrote) <= 1 or TargetUnit:DebuffRemainsP(S.Garrote) <= (AC.Exsanguinated(TargetUnit, "Garrote") and ExsanguinatedBleedTickTime or BleedTickTime))
        and (not AC.Exsanguinated(TargetUnit, "Garrote") or TargetUnit:DebuffRemainsP(S.Garrote) <= 1.5)
        and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold);
    end
    if Target:IsInRange("Melee") and Evaluate_Garrote_Target(Target)
      and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid()) then
      -- actions.maintain+=/pool_resource,for_next=1
      if Player:EnergyPredicted() < 45 then
        if AR.Cast(S.PoolEnergy) then return "Pool for Garrote (ST)"; end
      end
      if AR.Cast(S.Garrote) then return "Cast Garrote (Refresh)"; end
    end
    if AR.AoEON() then
      SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target, 4);
    end
  end
  -- actions.maintain+=/garrote,if=set_bonus.tier20_4pc&talent.exsanguinate.enabled&prev_gcd.1.rupture&cooldown.exsanguinate.remains<1&(!cooldown.vanish.up|time>12)
  if S.Garrote:IsCastable("Melee") and AC.Tier20_4Pc and S.Exsanguinate:IsAvailable() and Player:PrevGCD(1, S.Rupture)
    and S.Exsanguinate:CooldownRemainsP() < 1 and (not S.Vanish:CooldownUp() or AC.CombatTime() > 12) then
    if AR.Cast(S.Garrote) then return "Cast Garrote (T20)"; end
  end
  -- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&combo_points>=3&!ticking&mantle_duration<=0.2&target.time_to_die>6
  if S.Rupture:IsCastable("Melee") and not S.Exsanguinate:IsAvailable() and Player:ComboPoints() >= 3
    and not Target:DebuffP(S.Rupture) and Rogue.MantleDuration() <= 0.2
    and (Target:FilteredTimeToDie(">", 6) or Target:TimeToDieIsNotValid())
    and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
    if AR.Cast(S.Rupture) then return "Cast Rupture"; end
  end
  return false;
end
-- # Builders
local function Build ()
  if S.Hemorrhage:IsCastable() then
    -- actions.build=hemorrhage,if=refreshable
    if Target:IsInRange("Melee") and Target:DebuffRefreshableP(S.Hemorrhage, 6) then
      if AR.Cast(S.Hemorrhage) then return "Cast Hemorrhage"; end
    end
    -- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+equipped.insignia_of_ravenholdt
    if AR.AoEON() and Cache.EnemiesCount[10] < 2 + (I.InsigniaofRavenholdt:IsEquipped() and 1 or 0) then
      local BestUnit, BestUnitTTD = nil, 0;
      for _, CycleUnit in pairs(Cache.Enemies["Melee"]) do
        if Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD)
          and CycleUnit:DebuffRefreshableP(S.Hemorrhage, 6) and CycleUnit:DebuffP(S.Rupture) then
          BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Hemorrhage);
      end
    end
  end
  -- actions.build+=/fan_of_knives,if=buff.the_dreadlords_deceit.stack>=29
  if S.FanofKnives:IsCastable("Melee") and Player:BuffStack(S.DreadlordsDeceit) >= 29 then
    if AR.Cast(S.FanofKnives) then return "Cast Fan of Knives (Dreadlord's Deceit)"; end
  end
  -- # Mutilate is worth using over FoK for Exsanguinate builds in some 2T scenarios.
  -- actions.build+=/mutilate,if=talent.exsanguinate.enabled&(debuff.vendetta.up|combo_points<=2)
  if S.Mutilate:IsCastable("Melee") and S.Exsanguinate:IsAvailable() and (Target:DebuffP(S.Vendetta) or Player:ComboPoints() <= 2) then
    if AR.Cast(S.Mutilate) then return "Cast Mutilate (Exsanguinate)"; end
  end
  if S.FanofKnives:IsCastable() then
    -- actions.build+=/fan_of_knives,if=spell_targets>1+equipped.insignia_of_ravenholdt
    if Cache.EnemiesCount[10] > 1 + (I.InsigniaofRavenholdt:IsEquipped() and 1 or 0) then
      if AR.Cast(S.FanofKnives) then return "Cast Fan of Knives"; end
    end
    -- actions.build+=/fan_of_knives,if=combo_points>=3+talent.deeper_stratagem.enabled&artifact.poison_knives.rank>=5|fok_rotation
    if Player:ComboPoints() >= 3 + (S.DeeperStratagem:IsAvailable() and 1 or 0) and S.PoisonKnives:ArtifactRank() >= 5 or Settings.Assassination.FoKRotation then
      if AR.Cast(S.FanofKnives) then return "Cast Fan of Knives (Rotational)"; end
    end
  end
  if S.Mutilate:IsCastable() then
    -- actions.build+=/mutilate,cycle_targets=1,if=dot.deadly_poison_dot.refreshable
    if Target:IsInRange("Melee") and Target:DebuffRefreshableP(S.DeadlyPoisonDebuff, 4) then
      if AR.Cast(S.Mutilate) then return "Cast Mutilate (DoT Refresh)"; end
    end
    if AR.AoEON() then
      local BestUnit, BestUnitTTD = nil, 0;
      for _, CycleUnit in pairs(Cache.Enemies["Melee"]) do
        if Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD)
          and CycleUnit:DebuffRefreshableP(S.DeadlyPoisonDebuff, 4) then
          BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, S.Mutilate);
      end
    end
    -- actions.build+=/mutilate
    if Target:IsInRange("Melee") then
      if AR.Cast(S.Mutilate) then return "Cast Mutilate"; end
    end
  end
  return false;
end
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
  local PoisonRefreshTime = Player:AffectingCombat() and Settings.Assassination.PoisonRefreshCombat*60 or Settings.Assassination.PoisonRefresh*60;
  -- Lethal Poison
  if Player:BuffRemainsP(S.DeadlyPoison) <= PoisonRefreshTime
    and Player:BuffRemainsP(S.WoundPoison) <= PoisonRefreshTime then
    AR.CastSuggested(S.DeadlyPoison);
  end
  -- Non-Lethal Poison
  if Player:BuffRemainsP(S.CripplingPoison) <= PoisonRefreshTime
    and Player:BuffRemainsP(S.LeechingPoison) <= PoisonRefreshTime then
    if S.LeechingPoison:IsAvailable() then
      AR.CastSuggested(S.LeechingPoison);
    else
      AR.CastSuggested(S.CripplingPoison);
    end
  end

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Stealth
    if not Player:Buff(S.VanishBuff) then
      ShouldReturn = Rogue.Stealth(Stealth);
      if ShouldReturn then return ShouldReturn; end
    end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
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
    -- actions+=/run_action_list,name=stealthed,if=stealthed.rogue
    if Player:IsStealthed(true, false) then
      ShouldReturn = Stealthed();
      if ShouldReturn then return ShouldReturn .. " (Stealthed)"; end
      if AR.Cast(S.PoolEnergy) then return "Stealthed Pooling"; end
      return;
    end
    -- actions+=/run_action_list,name=aoe,if=spell_targets.fan_of_knives>2
    if AR.AoEON() and Cache.EnemiesCount[10] > 2 then
      ShouldReturn = AoE();
      if ShouldReturn then return ShouldReturn; end
      if AR.Cast(S.PoolEnergy) then return "AoE Pooling"; end
      return;
    end
    -- actions+=/call_action_list,name=maintain
    ShouldReturn = Maintain();
    if ShouldReturn then return ShouldReturn; end
    -- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)
    if (not AR.CDsON() or not S.Exsanguinate:IsAvailable() or S.Exsanguinate:CooldownRemainsP() > 2) then
      ShouldReturn = Finish();
      if ShouldReturn then return ShouldReturn; end
    end
    -- actions+=/call_action_list,name=build,if=combo_points.deficit>1+talent.anticipation.enabled*2|energy.deficit<=25+variable.energy_regen_combined
    if Player:ComboPointsDeficit() > 1 + (S.Anticipation:IsAvailable() and 2 or 0) or Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined then
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

-- Last Update: 01/29/2018

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
-- actions+=/run_action_list,name=stealthed,if=stealthed.rogue
-- actions+=/run_action_list,name=aoe,if=spell_targets.fan_of_knives>2
-- actions+=/call_action_list,name=maintain
-- # The 'active_dot.rupture>=spell_targets.rupture' means that we don't want to envenom as long as we can multi-rupture (i.e. units that don't have rupture yet).
-- actions+=/call_action_list,name=finish,if=(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)
-- actions+=/call_action_list,name=build,if=combo_points.deficit>1+talent.anticipation.enabled*2|energy.deficit<=25+variable.energy_regen_combined

-- # AoE
-- actions.aoe=envenom,if=!buff.envenom.up&combo_points>=cp_max_spend
-- actions.aoe+=/rupture,cycle_targets=1,if=combo_points>=cp_max_spend&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
-- actions.aoe+=/envenom,if=combo_points>=cp_max_spend
-- actions.aoe+=/fan_of_knives

-- # Builders
-- actions.build=hemorrhage,if=refreshable
-- actions.build+=/hemorrhage,cycle_targets=1,if=refreshable&dot.rupture.ticking&spell_targets.fan_of_knives<2+equipped.insignia_of_ravenholdt
-- actions.build+=/fan_of_knives,if=buff.the_dreadlords_deceit.stack>=29
-- # Mutilate is worth using over FoK for Exsanguinate builds in some 2T scenarios.
-- actions.build+=/mutilate,if=talent.exsanguinate.enabled&(debuff.vendetta.up|combo_points<=2)
-- actions.build+=/fan_of_knives,if=spell_targets>1+equipped.insignia_of_ravenholdt
-- actions.build+=/fan_of_knives,if=combo_points>=3+talent.deeper_stratagem.enabled&artifact.poison_knives.rank>=5|fok_rotation
-- actions.build+=/mutilate,cycle_targets=1,if=dot.deadly_poison_dot.refreshable
-- actions.build+=/mutilate

-- # Cooldowns
-- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|debuff.vendetta.up&cooldown.vanish.remains<5
-- actions.cds+=/blood_fury,if=debuff.vendetta.up
-- actions.cds+=/berserking,if=debuff.vendetta.up
-- actions.cds+=/arcane_torrent,if=dot.kingsbane.ticking&!buff.envenom.up&energy.deficit>=15+variable.energy_regen_combined*gcd.remains*1.1
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
-- actions.cds+=/vendetta,if=!talent.exsanguinate.enabled|dot.rupture.ticking
-- actions.cds+=/exsanguinate,if=!set_bonus.tier20_4pc&(prev_gcd.1.rupture&dot.rupture.remains>4+4*cp_max_spend&!stealthed.rogue|dot.garrote.pmultiplier>1&!cooldown.vanish.up&buff.subterfuge.up)
-- actions.cds+=/exsanguinate,if=set_bonus.tier20_4pc&dot.garrote.remains>20&dot.rupture.remains>4+4*cp_max_spend
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&!talent.exsanguinate.enabled&combo_points>=cp_max_spend&mantle_duration=0&debuff.vendetta.up
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&talent.exsanguinate.enabled&combo_points>=cp_max_spend&mantle_duration=0&cooldown.exsanguinate.remains<1
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&equipped.mantle_of_the_master_assassin&(debuff.vendetta.up|target.time_to_die<10)&mantle_duration=0
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&!equipped.mantle_of_the_master_assassin&!stealthed.rogue&dot.garrote.refreshable&((spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives)|(spell_targets.fan_of_knives>=4&combo_points.deficit>=4))
-- actions.cds+=/vanish,if=talent.shadow_focus.enabled&variable.energy_time_to_max_combined>=2&combo_points.deficit>=4
-- actions.cds+=/toxic_blade,if=combo_points.deficit>=1+(mantle_duration>=0.2)&dot.rupture.remains>8&cooldown.vendetta.remains>10
-- actions.cds+=/kingsbane,if=combo_points.deficit>=1+(mantle_duration>=0.2)&!stealthed.rogue&(!cooldown.toxic_blade.ready|!talent.toxic_blade.enabled&buff.envenom.up)

-- # Finishers
-- actions.finish=death_from_above,if=combo_points>=5
-- actions.finish+=/envenom,if=talent.anticipation.enabled&combo_points>=5&((debuff.toxic_blade.up&buff.virulent_poisons.remains<2)|mantle_duration>=0.2|buff.virulent_poisons.remains<0.2|energy.deficit<=25+variable.energy_regen_combined)
-- actions.finish+=/envenom,if=talent.anticipation.enabled&combo_points>=4&!buff.virulent_poisons.up
-- actions.finish+=/envenom,if=!talent.anticipation.enabled&combo_points>=4+(talent.deeper_stratagem.enabled&!set_bonus.tier19_4pc)&(debuff.vendetta.up|debuff.toxic_blade.up|mantle_duration>=0.2|debuff.surge_of_toxins.remains<0.2|energy.deficit<=25+variable.energy_regen_combined)
-- actions.finish+=/envenom,if=talent.elaborate_planning.enabled&combo_points>=3+!talent.exsanguinate.enabled&buff.elaborate_planning.remains<0.2

-- # Maintain
-- actions.maintain=rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2+artifact.urge_to_kill.enabled)))
-- actions.maintain+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>6
-- actions.maintain+=/pool_resource,for_next=1
-- actions.maintain+=/garrote,cycle_targets=1,if=(!talent.subterfuge.enabled|!(cooldown.vanish.up&cooldown.vendetta.remains<=4))&combo_points.deficit>=1&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
-- actions.maintain+=/garrote,if=set_bonus.tier20_4pc&talent.exsanguinate.enabled&prev_gcd.1.rupture&cooldown.exsanguinate.remains<1&(!cooldown.vanish.up|time>12)
-- actions.maintain+=/rupture,if=!talent.exsanguinate.enabled&combo_points>=3&!ticking&mantle_duration=0&target.time_to_die>6

-- # Stealthed
-- actions.stealthed=mutilate,if=talent.shadow_focus.enabled&dot.garrote.ticking
-- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&combo_points.deficit>=1&set_bonus.tier20_4pc&((dot.garrote.remains<=13&!debuff.toxic_blade.up)|pmultiplier<=1)&!exsanguinated
-- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&combo_points.deficit>=1&!set_bonus.tier20_4pc&refreshable&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>2
-- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&combo_points.deficit>=1&!set_bonus.tier20_4pc&remains<=10&pmultiplier<=1&!exsanguinated&target.time_to_die-remains>2
-- actions.stealthed+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>6
-- actions.stealthed+=/rupture,if=talent.exsanguinate.enabled&talent.nightstalker.enabled&target.time_to_die-remains>6
-- actions.stealthed+=/envenom,if=combo_points>=cp_max_spend
-- actions.stealthed+=/garrote,if=!talent.subterfuge.enabled&target.time_to_die-remains>4
-- actions.stealthed+=/mutilate

