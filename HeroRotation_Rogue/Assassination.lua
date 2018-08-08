--- Localize Vars
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
local pairs = pairs;

--- APL Local Vars
-- Commons
local Everyone = HR.Commons.Everyone;
local Rogue = HR.Commons.Rogue;
-- Spells
if not Spell.Rogue then Spell.Rogue = {}; end
Spell.Rogue.Assassination = {
  -- Racials
  ArcanePulse           = Spell(260364),
  ArcaneTorrent         = Spell(25046),
  Berserking            = Spell(26297),
  BloodFury             = Spell(20572),
  LightsJudgment        = Spell(255647),
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
  Blindside             = Spell(111240),
  BlindsideBuff         = Spell(121153),
  CrimsonTempest        = Spell(121411),
  DeeperStratagem       = Spell(193531),
  Exsanguinate          = Spell(200806),
  HiddenBladesBuff      = Spell(270070),
  InternalBleeding      = Spell(154953),
  MarkedforDeath        = Spell(137619),
  MasterAssassin        = Spell(255989),
  Nightstalker          = Spell(14062),
  Subterfuge            = Spell(108208),
  ToxicBlade            = Spell(245388),
  ToxicBladeDebuff      = Spell(245389),
  VenomRush             = Spell(152152),
  -- Defensive
  CrimsonVial           = Spell(185311),
  Feint                 = Spell(1966),
  -- Utility
  Blind                 = Spell(2094),
  Kick                  = Spell(1766),
  -- Poisons
  CripplingPoison       = Spell(3408),
  DeadlyPoison          = Spell(2823),
  DeadlyPoisonDebuff    = Spell(2818),
  WoundPoison           = Spell(8679),
  WoundPoisonDebuff     = Spell(8680),
  -- Misc
  TheDreadlordsDeceit   = Spell(208693),
  PoolEnergy            = Spell(9999000010)
};
local S = Spell.Rogue.Assassination;
-- Items
if not Item.Rogue then Item.Rogue = {}; end
Item.Rogue.Assassination = {
  -- Nothing
};
local I = Item.Rogue.Assassination;

-- Spells Damage
S.Envenom:RegisterDamage(
  -- Envenom DMG Formula:
  --  AP * CP * Env_APCoef * Aura_M * ToxicB_M * DS_M * Mastery_M * Versa_M
  function ()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() *
      -- Combo Points
      Rogue.CPSpend() *
      -- Envenom AP Coef
      0.16 *
      -- Aura Multiplier (SpellID: 137037)
      1.27 *
      -- Toxic Blade Multiplier
      (Target:DebuffP(S.ToxicBladeDebuff) and 1.3 or 1) *
      -- Deeper Stratagem Multiplier
      (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
      -- Mastery Finisher Multiplier
      (1 + Player:MasteryPct()/100) *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
);
S.Mutilate:RegisterDamage(
  function ()
    return
      -- Attack Power (MH Factor + OH Factor)
      (Player:AttackPowerDamageMod() + Player:AttackPowerDamageMod(true)) *
      -- Mutilate Coefficient
      0.35 *
      -- Aura Multiplier (SpellID: 137037)
      1.27 *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100);
  end
);
local function NighstalkerMultiplier ()
  return S.Nightstalker:IsAvailable() and Player:IsStealthed(true, false) and 1.5 or 1;
end
local function SubterfugeGarroteMultiplier ()
  return S.Subterfuge:IsAvailable() and Player:IsStealthed(true, false) and 2 or 1;
end
S.Garrote:RegisterPMultiplier(
  {NighstalkerMultiplier},
  {SubterfugeGarroteMultiplier}
);
S.Rupture:RegisterPMultiplier(
  {NighstalkerMultiplier}
);

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local BleedTickTime, ExsanguinatedBleedTickTime = 2 / Player:SpellHaste(), 1 / Player:SpellHaste();
local Stealth;
local RuptureThreshold, CrimsonTempestThreshold, RuptureDMGThreshold, GarroteDMGThreshold;
local ComboPoints, ComboPointsDeficit, Energy_Regen_Combined;

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  Assassination = HR.GUISettings.APL.Rogue.Assassination
};

local function num(val)
  if val then return 1 else return 0 end
end

-- Handle CastLeftNameplate Suggestions for DoT Spells
local function SuggestCycleDoT(DoTSpell, DoTEvaluation, DoTMinTTD)
  -- Prefer melee cycle units
  local BestUnit, BestUnitTTD = nil, DoTMinTTD;
  local TargetGUID = Target:GUID();
  for _, CycleUnit in pairs(Cache.Enemies["Melee"]) do
    if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemainsP(DoTSpell))
    and DoTEvaluation(CycleUnit) then
      BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie();
    end
  end
  if BestUnit then
    HR.CastLeftNameplate(BestUnit, DoTSpell);
  -- Check ranged units next, if the RangedMultiDoT option is enabled
  elseif Settings.Assassination.RangedMultiDoT then
    BestUnit, BestUnitTTD = nil, DoTMinTTD;
    for _, CycleUnit in pairs(Cache.Enemies[10]) do
      if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemainsP(DoTSpell))
      and DoTEvaluation(CycleUnit) then
        BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie();
      end
    end
    if BestUnit then
      HR.CastLeftNameplate(BestUnit, DoTSpell);
    end
  end
end

-- Master Assassin Remains Check
local MasterAssassinBuff, NominalDuration = Spell(256735), 3;
local function MasterAssassinRemains ()
  if Player:BuffRemains(MasterAssassinBuff) < 0 then
    return Player:GCDRemains() + NominalDuration;
  else
    return Player:BuffRemainsP(MasterAssassinBuff);
  end
end

local MythicDungeon;
do
  local SappedSoulSpells = {
    {S.Kick, "Cast Kick (Sapped Soul)", function () return Target:IsInRange("Melee"); end},
    {S.Feint, "Cast Feint (Sapped Soul)", function () return true; end},
    {S.CrimsonVial, "Cast Crimson Vial (Sapped Soul)", function () return true; end}
  };
  MythicDungeon = function ()
    -- Sapped Soul
    if HL.MythicDungeon() == "Sapped Soul" then
      for i = 1, #SappedSoulSpells do
        local SappedSoulSpell = SappedSoulSpells[i];
        if SappedSoulSpell[1]:IsCastable() and SappedSoulSpell[3]() then
          HR.ChangePulseTimer(1);
          HR.Cast(SappedSoulSpell[1]);
          return SappedSoulSpell[2];
        end
      end
    end
    return false;
  end
end
local function TrainingScenario ()
  if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*ComboPoints then
    -- Kidney Shot
    if S.KidneyShot:IsCastable("Melee") and ComboPoints > 0 then
      if HR.Cast(S.KidneyShot) then return "Cast Kidney Shot (Unstable Explosion)"; end
    end
  end
  return false;
end
local Interrupts = {
  {S.Blind, "Cast Blind (Interrupt)", function () return true; end},
  {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return ComboPoints > 0; end}
}

-- APL Action Lists (and Variables)
-- # Cooldowns
local function CDs ()
  if Target:IsInRange("Melee") then
    -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|debuff.vendetta.up&cooldown.vanish.remains<5

    -- Racials
    if Target:Debuff(S.Vendetta) then
      -- actions.cds+=/blood_fury,if=debuff.vendetta.up
      if S.BloodFury:IsCastable() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury"; end
      end
      -- actions.cds+=/berserking,if=debuff.vendetta.up
      if S.Berserking:IsCastable() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking"; end
      end
    end

    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
    if S.MarkedforDeath:IsCastable() and ComboPointsDeficit >= Rogue.CPMaxSpend() then
      HR.CastSuggested(S.MarkedforDeath);
    end
    -- actions.cds+=/vendetta,if=dot.rupture.ticking
    if S.Vendetta:IsCastable() and Target:DebuffP(S.Rupture) then
      if HR.Cast(S.Vendetta, Settings.Assassination.GCDasOffGCD.Vendetta) then return "Cast Vendetta"; end
    end
    if S.Vanish:IsCastable() and not Player:IsTanking(Target) then
      -- actions.cds+=/vanish,if=talent.exsanguinate.enabled&(talent.nightstalker.enabled|talent.subterfuge.enabled&spell_targets.fan_of_knives<2)&combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1
      if S.Exsanguinate:IsAvailable() and (S.Nightstalker:IsAvailable() or S.Subterfuge:IsAvailable() and Cache.EnemiesCount[10] < 2)
        and ComboPoints >= Rogue.CPMaxSpend() and S.Exsanguinate:CooldownRemainsP() < 1 then
          if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Exsanguinate)"; end
      end
      -- actions.cds+=/vanish,if=talent.nightstalker.enabled&!talent.exsanguinate.enabled&combo_points>=cp_max_spend&debuff.vendetta.up
      if S.Nightstalker:IsAvailable() and not S.Exsanguinate:IsAvailable() and ComboPoints >= Rogue.CPMaxSpend() and Target:Debuff(S.Vendetta) then
        if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Nightstalker)"; end
      end
      -- actions.cds+=/vanish,if=talent.subterfuge.enabled&(!talent.exsanguinate.enabled|spell_targets.fan_of_knives>=2)&!stealthed.rogue&cooldown.garrote.up&dot.garrote.refreshable&(spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives|spell_targets.fan_of_knives>=4&combo_points.deficit>=4)
      if S.Subterfuge:IsAvailable() and (not S.Exsanguinate:IsAvailable() or Cache.EnemiesCount[10] >= 2) and not Player:IsStealthed(true, false)
        and S.Garrote:CooldownUp() and Target:DebuffRefreshableP(S.Garrote, 5.4)
        and ((Cache.EnemiesCount[10] <= 3 and ComboPointsDeficit >= 1+Cache.EnemiesCount[10]) or (Cache.EnemiesCount[10] >= 4 and ComboPointsDeficit >= 4)) then
        if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Subterfuge)"; end
      end
      -- actions.cds+=/vanish,if=talent.master_assassin.enabled&!stealthed.all&master_assassin_remains<=0&!dot.rupture.refreshable
      if S.MasterAssassin:IsAvailable() and not Player:IsStealthed(true, false) and MasterAssassinRemains() <= 0 and not Target:DebuffRefreshableP(S.Rupture, RuptureThreshold) then
        if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Master Assassin)"; end
      end
    end
    if S.Exsanguinate:IsCastable() then
      -- actions.cds+=/exsanguinate,if=dot.rupture.remains>4+4*cp_max_spend&!dot.garrote.refreshable
      if Target:DebuffRemainsP(S.Rupture) > 4+4*Rogue.CPMaxSpend() and not Target:DebuffRefreshableP(S.Garrote, 5.4) then
        if HR.Cast(S.Exsanguinate) then return "Cast Exsanguinate"; end
      end
    end
    -- actions.cds+=/toxic_blade,if=dot.rupture.ticking
    if S.ToxicBlade:IsCastable("Melee") and Target:DebuffP(S.Rupture) then
      if HR.Cast(S.ToxicBlade) then return "Cast Toxic Blade"; end
    end
  end
  return false;
end
-- # Stealthed
local function Stealthed ()
  -- actions.stealthed=rupture,if=combo_points>=4&(talent.nightstalker.enabled|talent.subterfuge.enabled&talent.exsanguinate.enabled&spell_targets.fan_of_knives<2|!ticking)&target.time_to_die-remains>6
  if S.Rupture:IsCastable("Melee") and ComboPoints >= 4
    and (S.Nightstalker:IsAvailable() or (S.Subterfuge:IsAvailable() and S.Exsanguinate:IsAvailable() and Cache.EnemiesCount[10] < 2) or not Target:DebuffP(S.Rupture))
    and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemainsP(S.Rupture)) or Target:TimeToDieIsNotValid()) then
    if HR.Cast(S.Rupture) then return "Cast Rupture (Exsanguinate)"; end
  end
  -- actions.stealthed+=/envenom,if=combo_points>=cp_max_spend
  if S.Envenom:IsCastable("Melee") and ComboPoints >= Rogue.CPMaxSpend() then
    if HR.Cast(S.Envenom) then return "Cast Envenom"; end
  end
  if S.Garrote:IsCastable("Melee") and S.Subterfuge:IsAvailable() then
    -- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&refreshable&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>2
    local function Evaluate_Garrote_Target_A(TargetUnit)
      return TargetUnit:DebuffRefreshableP(S.Garrote, 5.4)
        and (not HL.Exsanguinated(TargetUnit, "Garrote") or TargetUnit:DebuffRemainsP(S.Garrote) <= ExsanguinatedBleedTickTime*2)
        and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold);
    end
    if Target:IsInRange("Melee") and Evaluate_Garrote_Target_A(Target)
      and (Target:FilteredTimeToDie(">", 2, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid()) then
      if HR.Cast(S.Garrote) then return "Cast Garrote (Subterfuge, Refresh)"; end
    end
    if HR.AoEON() then
      SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target_A, 2);
    end
    -- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&pmultiplier<=1&!exsanguinated&target.time_to_die-remains>2
    local function Evaluate_Garrote_Target_B(TargetUnit)
      return TargetUnit:PMultiplier(S.Garrote) <= 1 and not HL.Exsanguinated(TargetUnit, "Garrote")
        and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold);
    end
    if Target:IsInRange("Melee") and Evaluate_Garrote_Target_B(Target)
      and (Target:FilteredTimeToDie(">", 2, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid()) then
      if HR.Cast(S.Garrote) then return "Cast Garrote (Subterfuge)"; end
    end
    if HR.AoEON() then
      SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target_B, 2);
    end
    -- actions.stealthed+=/garrote,if=talent.subterfuge.enabled&talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&prev_gcd.1.rupture&dot.rupture.remains>5+4*cp_max_spend
    if S.Exsanguinate:IsAvailable() and S.Exsanguinate:CooldownRemainsP() < 1 and Player:PrevGCD(1, S.Rupture) and Target:DebuffRemainsP(S.Rupture) > 5+4*Rogue.CPMaxSpend() then
      -- actions.stealthed+=/pool_resource,for_next=1
      if Player:EnergyPredicted() < 45 then
        if HR.Cast(S.PoolEnergy) then return "Pool for Garrote (Exsanguinate)"; end
      end
      if HR.Cast(S.Garrote) then return "Cast Garrote (Exsanguinate)"; end
    end
  end
end
-- # Damage over time abilities
local function Dot ()
  -- actions.dot=rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2)))
  if HR.CDsON() and S.Rupture:IsCastable("Melee") and ComboPoints > 0 and S.Exsanguinate:IsAvailable()
    and ((ComboPoints >= Rogue.CPMaxSpend() and S.Exsanguinate:CooldownRemainsP() < 1)
      or (not Target:DebuffP(S.Rupture) and (HL.CombatTime() > 10 or (ComboPoints >= 2)))) then
    if HR.Cast(S.Rupture) then return "Cast Rupture (Exsanguinate)"; end
  end
  -- actions.dot+=/garrote,cycle_targets=1,if=(!talent.subterfuge.enabled|!(cooldown.vanish.up&cooldown.vendetta.remains<=4))&combo_points.deficit>=1&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&(target.time_to_die-remains>4&spell_targets.fan_of_knives<=1|target.time_to_die-remains>12)
  if S.Garrote:IsCastable() and (not S.Subterfuge:IsAvailable() or not HR.CDsON() or not (S.Vanish:CooldownUp() and S.Vendetta:CooldownRemainsP() <= 4)) and ComboPointsDeficit >= 1 then
    local function Evaluate_Garrote_Target(TargetUnit)
      return TargetUnit:DebuffRefreshableP(S.Garrote, 5.4)
        and (TargetUnit:PMultiplier(S.Garrote) <= 1 or TargetUnit:DebuffRemainsP(S.Garrote) <= (HL.Exsanguinated(TargetUnit, "Garrote") and ExsanguinatedBleedTickTime or BleedTickTime))
        and (not HL.Exsanguinated(TargetUnit, "Garrote") or TargetUnit:DebuffRemainsP(S.Garrote) <= 1.5)
        and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold);
    end
    local ttdval = Cache.EnemiesCount[10] <= 1 and 4 or 12;
    if Target:IsInRange("Melee") and Evaluate_Garrote_Target(Target)
      and (Target:FilteredTimeToDie(">", ttdval, -Target:DebuffRemainsP(S.Garrote)) or Target:TimeToDieIsNotValid()) then
      -- actions.maintain+=/pool_resource,for_next=1
      if Player:EnergyPredicted() < 45 then
        if HR.Cast(S.PoolEnergy) then return "Pool for Garrote (ST)"; end
      end
      if HR.Cast(S.Garrote) then return "Cast Garrote (Refresh)"; end
    end
    if HR.AoEON() then
      SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target, ttdval);
    end
  end
  -- actions.dot+=/crimson_tempest,if=spell_targets>=2&remains<2+(spell_targets>=5)&combo_points>=4
  if HR.AoEON() and S.CrimsonTempest:IsCastable("Melee") and ComboPoints >= 4 and Cache.EnemiesCount[10] >= 2
    and Target:DebuffRemainsP(S.CrimsonTempest) < 2 + num(Cache.EnemiesCount[10] >= 5) then
    if HR.Cast(S.CrimsonTempest) then return "Cast Crimson Tempest"; end
  end
  -- actions.dot+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
  if ComboPoints >= 4 then
    local function Evaluate_Rupture_Target(TargetUnit)
      return TargetUnit:DebuffRefreshableP(S.Rupture, RuptureThreshold)
        and (TargetUnit:PMultiplier(S.Rupture) <= 1 or TargetUnit:DebuffRemainsP(S.Rupture) <= (HL.Exsanguinated(TargetUnit, "Rupture") and ExsanguinatedBleedTickTime or BleedTickTime))
        and (not HL.Exsanguinated(TargetUnit, "Rupture") or TargetUnit:DebuffRemainsP(S.Rupture) <= ExsanguinatedBleedTickTime*2)
        and Rogue.CanDoTUnit(TargetUnit, RuptureDMGThreshold);
    end
    if Target:IsInRange("Melee") and Evaluate_Rupture_Target(Target)
      and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemainsP(S.Rupture)) or Target:TimeToDieIsNotValid()) then
      if HR.Cast(S.Rupture) then return "Cast Rupture (Refresh)"; end
    end
    if HR.AoEON() then
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, 4);
    end
  end
  return false;
end
-- # Direct damage abilities
local function Direct ()
  -- actions.direct=envenom,if=combo_points>=4+talent.deeper_stratagem.enabled&(debuff.vendetta.up|debuff.toxic_blade.up|energy.deficit<=25+variable.energy_regen_combined|spell_targets.fan_of_knives>=2)&(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)
  if S.Envenom:IsCastable("Melee") and ComboPoints >= 4 + (S.DeeperStratagem:IsAvailable() and 1 or 0)
    and (Target:DebuffP(S.Vendetta) or Target:DebuffP(S.ToxicBladeDebuff) or Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined or Cache.EnemiesCount[10] >= 2)
    and (not S.Exsanguinate:IsAvailable() or S.Exsanguinate:CooldownRemainsP() > 2) then
    if HR.Cast(S.Envenom) then return "Cast Envenom"; end
  end

  -------------------------------------------------------------------
  -------------------------------------------------------------------
  -- actions.direct+=/variable,name=use_filler,value=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined|spell_targets.fan_of_knives>=2
  -- This is used in all following fillers, so we just return false if not true and won't consider these.
  if not (ComboPointsDeficit > 1 or Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined or Cache.EnemiesCount[10] >= 2) then
    return false;
  end
  -------------------------------------------------------------------
  -------------------------------------------------------------------

  -- actions.direct+=/fan_of_knives,if=variable.use_filler&(buff.hidden_blades.stack>=19|spell_targets.fan_of_knives>=2+stealthed.rogue|buff.the_dreadlords_deceit.stack>=29)
  if HR.AoEON() and S.FanofKnives:IsCastable("Melee") and (Player:BuffStack(S.HiddenBladesBuff) >= 19 or Cache.EnemiesCount[10] >= 2 + num(Player:IsStealthed(true, false)) or Player:BuffStack(S.TheDreadlordsDeceit) >= 29) then
    if HR.Cast(S.FanofKnives) then return "Cast Fan of Knives"; end
  end
  -- actions.direct+=/blindside,if=variable.use_filler&(buff.blindside.up|!talent.venom_rush.enabled)
  if S.Blindside:IsCastable("Melee") and (Player:BuffP(S.BlindsideBuff) or (not S.VenomRush:IsAvailable() and Target:HealthPercentage() < 30)) then
    if HR.Cast(S.Blindside) then return "Cast Blindside"; end
  end
  -- actions.direct+=/mutilate,if=variable.use_filler
  if S.Mutilate:IsCastable("Melee") then
    if HR.Cast(S.Mutilate) then return "Cast Mutilate"; end
  end
  return false;
end
-- APL Main
local function APL ()
  -- Spell ID Changes check
  Stealth = S.Subterfuge:IsAvailable() and S.Stealth2 or S.Stealth; -- w/ or w/o Subterfuge Talent

  -- Unit Update
  HL.GetEnemies(50); -- Used for Rogue.PoisonedBleeds()
  HL.GetEnemies(30); -- Used for Poisoned Knife Poison refresh
  HL.GetEnemies(10, true); -- Fan of Knives
  HL.GetEnemies("Melee"); -- Melee
  Everyone.AoEToggleEnemiesUpdate();

  -- Compute Cache
  ComboPoints = Player:ComboPoints();
  ComboPointsDeficit = Player:ComboPointsMax() - ComboPoints;
  RuptureThreshold = (4 + ComboPoints * 4) * 0.3;
  CrimsonTempestThreshold = (2 + ComboPoints * 2) * 0.3;
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
    HR.CastSuggested(S.DeadlyPoison);
  end
  -- Non-Lethal Poison
  if Player:BuffRemainsP(S.CripplingPoison) <= PoisonRefreshTime then
    HR.CastSuggested(S.CripplingPoison);
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

    -- actions=variable,name=energy_regen_combined,value=energy.regen+poisoned_bleeds*7%(2*spell_haste)
    Energy_Regen_Combined = Player:EnergyRegen() + Rogue.PoisonedBleeds() * 7 / (2 * Player:SpellHaste());

    -- actions+=/call_action_list,name=stealthed,if=stealthed.rogue
    if Player:IsStealthed(true, false) then
      ShouldReturn = Stealthed();
      if ShouldReturn then return ShouldReturn .. " (Stealthed)"; end
    end
    -- actions+=/call_action_list,name=cds
    if HR.CDsON() then
      ShouldReturn = CDs();
      if ShouldReturn then return ShouldReturn; end
    end
    -- actions+=/call_action_list,name=dot
    ShouldReturn = Dot();
    if ShouldReturn then return ShouldReturn; end
    -- actions+=/call_action_list,name=direct
    ShouldReturn = Direct();
    if ShouldReturn then return ShouldReturn; end
    -- actions+=/arcane_torrent,if=energy.deficit>=15+variable.energy_regen_combined
    if S.ArcaneTorrent:IsCastableP("Melee") and Player:EnergyDeficitPredicted() > 15 + Energy_Regen_Combined then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Torrent"; end
    end
    -- actions+=/arcane_pulse
    if S.ArcanePulse:IsCastableP("Melee") then
      if HR.Cast(S.ArcanePulse, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Pulse"; end
    end
    -- actions+=/lights_judgment
    if S.LightsJudgment:IsCastableP("Melee") then
      if HR.Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Lights Judgment"; end
    end
    -- Poisoned Knife Out of Range [EnergyCap] or [PoisonRefresh]
    if S.PoisonedKnife:IsCastable(30) and not Player:IsStealthed(true, true)
      and ((not Target:IsInRange(10) and Player:EnergyTimeToMax() <= Player:GCD()*1.2)
        or (not Target:IsInRange("Melee") and Target:DebuffRefreshableP(S.DeadlyPoisonDebuff, 4))) then
      if HR.Cast(S.PoisonedKnife) then return "Cast Poisoned Knife"; end
    end
    -- Trick to take in consideration the Recovery Setting
    if S.Mutilate:IsCastable("Melee") then
      if HR.Cast(S.PoolEnergy) then return "Normal Pooling"; end
    end
  end
end

HR.SetAPL(259, APL);

-- Last Update: 2018-08-07

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/apply_poison
-- actions.precombat+=/stealth
-- actions.precombat+=/potion
-- actions.precombat+=/marked_for_death,precombat_seconds=5,if=raid_event.adds.in>15
--
-- # Executed every time the actor is available.
-- actions=variable,name=energy_regen_combined,value=energy.regen+poisoned_bleeds*7%(2*spell_haste)
-- actions+=/call_action_list,name=stealthed,if=stealthed.rogue
-- actions+=/call_action_list,name=cds
-- actions+=/call_action_list,name=dot
-- actions+=/call_action_list,name=direct
-- actions+=/arcane_torrent,if=energy.deficit>=15+variable.energy_regen_combined
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
--
-- # Stealthed Actions
-- # Nighstalker, or Subt+Exsg on 1T: Snapshot Rupture; Also use Rupture over Envenom if it's not applied (Opener)
-- actions.stealthed=rupture,if=combo_points>=4&(talent.nightstalker.enabled|talent.subterfuge.enabled&talent.exsanguinate.enabled&spell_targets.fan_of_knives<2|!ticking)&target.time_to_die-remains>6
-- actions.stealthed+=/envenom,if=combo_points>=cp_max_spend
-- # Subterfuge: Apply or Refresh with buffed Garrotes
-- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&refreshable&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>2
-- # Subterfuge: Override normal Garrotes with snapshot versions
-- actions.stealthed+=/garrote,cycle_targets=1,if=talent.subterfuge.enabled&pmultiplier<=1&!exsanguinated&target.time_to_die-remains>2
-- # Subterfuge + Exsg: Even override a snapshot Garrote right after Rupture before Exsanguination
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/garrote,if=talent.subterfuge.enabled&talent.exsanguinate.enabled&cooldown.exsanguinate.remains<1&prev_gcd.1.rupture&dot.rupture.remains>5+4*cp_max_spend
--
-- # Potion
-- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|debuff.vendetta.up&cooldown.vanish.remains<5
--
-- # Racials
-- actions.cds+=/blood_fury,if=debuff.vendetta.up
-- actions.cds+=/berserking,if=debuff.vendetta.up
--
-- # Cooldowns
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
-- actions.cds+=/vendetta,if=dot.rupture.ticking
--
-- # Vanish with Exsg + (Nightstalker, or Subterfuge only on 1T): Maximum CP and Exsg ready for next GCD
-- actions.cds+=/vanish,if=talent.exsanguinate.enabled&(talent.nightstalker.enabled|talent.subterfuge.enabled&spell_targets.fan_of_knives<2)&combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1
-- # Vanish with Nightstalker + No Exsg: Maximum CP and Vendetta up
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&!talent.exsanguinate.enabled&combo_points>=cp_max_spend&debuff.vendetta.up
-- # Vanish with Subterfuge + (No Exsg or 2T+): No stealth/subterfuge, Garrote Refreshable, enough space for incoming Garrote CP
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&(!talent.exsanguinate.enabled|spell_targets.fan_of_knives>=2)&!stealthed.rogue&cooldown.garrote.up&dot.garrote.refreshable&(spell_targets.fan_of_knives<=3&combo_points.deficit>=1+spell_targets.fan_of_knives|spell_targets.fan_of_knives>=4&combo_points.deficit>=4)
-- # Vanish with Master Assasin: No stealth and no active MA buff, Rupture not in refresh range
-- actions.cds+=/vanish,if=talent.master_assassin.enabled&!stealthed.all&master_assassin_remains<=0&!dot.rupture.refreshable
--
-- # Exsanguinate when both Rupture and Garrote are up for long enough
-- actions.cds+=/exsanguinate,if=dot.rupture.remains>4+4*cp_max_spend&!dot.garrote.refreshable
-- actions.cds+=/toxic_blade,if=dot.rupture.ticking
--
-- # Damage over time abilities
-- # Special Rupture setup for Exsg
-- actions.dot=rupture,if=talent.exsanguinate.enabled&((combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1)|(!ticking&(time>10|combo_points>=2)))
-- # Garrote upkeep, also tries to use it as a special generator for the last CP before a finisher
-- actions.dot+=/pool_resource,for_next=1
-- actions.dot+=/garrote,cycle_targets=1,if=(!talent.subterfuge.enabled|!(cooldown.vanish.up&cooldown.vendetta.remains<=4))&combo_points.deficit>=1&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&(target.time_to_die-remains>4&spell_targets.fan_of_knives<=1|target.time_to_die-remains>12)
-- # Crimson Tempest only on multiple targets at 4+ CP when running out in 2s (up to 4 targets) or 3s (5+ targets)
-- actions.dot+=/crimson_tempest,if=spell_targets>=2&remains<2+(spell_targets>=5)&combo_points>=4
-- # Keep up Rupture at 4+ on all targets (when living long enough and not snapshot)
-- actions.dot+=/rupture,cycle_targets=1,if=combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time)&(!exsanguinated|remains<=tick_time*2)&target.time_to_die-remains>4
--
-- # Direct damage abilities
-- # Envenom at 4+ (5+ with DS) CP. Immediately on 2+ targets, with Vendetta, or with TB; otherwise wait for some energy. Also wait if Exsg combo is coming up.
-- actions.direct=envenom,if=combo_points>=4+talent.deeper_stratagem.enabled&(debuff.vendetta.up|debuff.toxic_blade.up|energy.deficit<=25+variable.energy_regen_combined|spell_targets.fan_of_knives>=2)&(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)
-- actions.direct+=/variable,name=use_filler,value=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined|spell_targets.fan_of_knives>=2
-- actions.direct+=/fan_of_knives,if=variable.use_filler&(buff.hidden_blades.stack>=19|spell_targets.fan_of_knives>=2+stealthed.rogue|buff.the_dreadlords_deceit.stack>=29)
-- #Loss LOL, even at 3 Ranks
-- #actions.direct+=/poisoned_knife,if=variable.use_filler&buff.sharpened_blades.stack>=39
-- actions.direct+=/blindside,if=variable.use_filler&(buff.blindside.up|!talent.venom_rush.enabled)
-- actions.direct+=/mutilate,if=variable.use_filler

