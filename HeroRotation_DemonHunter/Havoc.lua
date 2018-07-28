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

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.DemonHunter then Spell.DemonHunter = {}; end
Spell.DemonHunter.Havoc = {
  -- Racials
  ArcaneTorrent                 = Spell(80483),
  Shadowmeld                    = Spell(58984),
  -- Abilities
  Annihilation                  = Spell(201427),
  BladeDance                    = Spell(188499),
  ChaosStrike                   = Spell(162794),
  ChaosNova                     = Spell(179057),
  DeathSweep                    = Spell(210152),
  DemonsBite                    = Spell(162243),
  Disrupt                       = Spell(183752),
  EyeBeam                       = Spell(198013),
  FelRush                       = Spell(195072),
  Metamorphosis                 = Spell(191427),
  MetamorphosisImpact           = Spell(200166),
  MetamorphosisBuff             = Spell(162264),
  ThrowGlaive                   = Spell(185123),
  VengefulRetreat               = Spell(198793),
  -- Talents
  BlindFury                     = Spell(203550),
  CycleOfHatred                 = Spell(258887),
  DarkSlash                     = Spell(258860),
  DemonBlades                   = Spell(203555),
  Demonic                       = Spell(213410),
  DemonicAppetite               = Spell(206478),
  FelBarrage                    = Spell(258925),
  Felblade                      = Spell(232893),
  FelEruption                   = Spell(211881),
  FelMastery                    = Spell(192939),
  FirstBlood                    = Spell(206416),
  ImmolationAura                = Spell(258920),
  InsatiableHunger              = Spell(258876),
  MasterOfTheGlaive             = Spell(203556),
  Momentum                      = Spell(206476),
  MomentumBuff                  = Spell(208628),
  Nemesis                       = Spell(206491),
  PreparedBuff                  = Spell(203650),
  TrailOfRuin                   = Spell(258881),
  -- Set Bonuses
  T21_4pc_Buff                  = Spell(252165),
  -- Misc
  PoolEnergy                    = Spell(9999000010),
};
local S = Spell.DemonHunter.Havoc;

-- Items
if not Item.DemonHunter then Item.DemonHunter = {}; end
Item.DemonHunter.Havoc = {
  -- Legendaries
  DelusionsOfGrandeur           = Item(144279, {3}),
  -- Trinkets
  ConvergenceofFates            = Item(140806, {13, 14}),
  KiljaedensBurningWish         = Item(144259, {13, 14}),
  DraughtofSouls                = Item(140808, {13, 14}),
  VialofCeaselessToxins         = Item(147011, {13, 14}),
  UmbralMoonglaives             = Item(147012, {13, 14}),
  SpecterofBetrayal             = Item(151190, {13, 14}),
  VoidStalkersContract          = Item(151307, {13, 14}),
  ForgefiendsFabricator         = Item(151963, {13, 14}),
  -- Potion
  ProlongedPower                = Item(142117),
};
local I = Item.DemonHunter.Havoc;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local CleaveRangeID = tostring(S.Disrupt:ID()); -- 20y range

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  Havoc = HR.GUISettings.APL.DemonHunter.Havoc
};

-- Interrupts List
local StunInterrupts = {
  {S.FelEruption, "Cast Fel Eruption (Interrupt)", function () return true; end},
  {S.ChaosNova, "Cast Chaos Nova (Interrupt)", function () return true; end},
};

-- Melee Is In Range w/ Movement Handlers
local function IsInMeleeRange ()
  if S.Felblade:TimeSinceLastCast() < Player:GCD() then
    return true;
  elseif S.Metamorphosis:TimeSinceLastCast() < Player:GCD() then
    return true;
  end

  return Target:IsInRange("Melee");
end

-- Special Havoc Functions
local function IsMetaExtendedByDemonic()
  if not Player:BuffP(S.MetamorphosisBuff) then
    return false;
  elseif(S.EyeBeam:TimeSinceLastCast() < S.MetamorphosisImpact:TimeSinceLastCast()) then
    return true;
  end

  return false;
end

-- Variables
-- variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=(3-talent.trail_of_ruin.enabled)
local function BladeDance()
  return S.FirstBlood:IsAvailable() or HL.Tier20_4Pc or (HR.AoEON() and Cache.EnemiesCount[8] >= 3 - (S.TrailOfRuin:IsAvailable() and 1 or 0));
end
-- variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
local function WaitingForNemesis()
  if not HR.CDsON() then
    return false;
  end
  return not (not S.Nemesis:IsAvailable() or S.Nemesis:IsReady() or S.Nemesis:CooldownRemainsP() > Target:TimeToDie() or S.Nemesis:CooldownRemainsP() > 60);
end
-- variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)
local function PoolingForMeta()
  if not HR.CDsON() then
    return false;
  end
  return not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemainsP() < 6 and Player:FuryDeficit() > 30
    and (not WaitingForNemesis() or S.Nemesis:CooldownRemainsP() < 10);
end
-- variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
local function PoolingForBladeDance()
  return BladeDance() and (Player:Fury() < (75 - (S.FirstBlood:IsAvailable() and 20 or 0)));
end
-- variable,name=waiting_for_dark_slash,value=talent.dark_slash.enabled&!variable.pooling_for_blade_dance&!variable.pooling_for_meta&cooldown.dark_slash.up
local function WaitingForDarkSlash()
  return S.DarkSlash:IsAvailable() and not PoolingForBladeDance() and not PoolingForMeta() and S.DarkSlash:IsReady();
end
-- variable,name=waiting_for_momentum,value=talent.momentum.enabled&!buff.momentum.up
local function WaitingForMomentum()
  return S.Momentum:IsAvailable() and not Player:BuffP(S.MomentumBuff);
end


-- Main APL
local function APL()
  local function Cooldown()
    -- metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis)|target.time_to_die<25
    if S.Metamorphosis:IsCastable()
      and (not (S.Demonic:IsAvailable() or PoolingForMeta() or WaitingForNemesis()) or Target:TimeToDie() < 25) then
      if HR.Cast(S.Metamorphosis, Settings.Havoc.OffGCDasOffGCD.Metamorphosis) then return "Cast Metamorphosis"; end
    end
    -- metamorphosis,if=talent.demonic.enabled&buff.metamorphosis.up
    if S.Metamorphosis:IsCastable() and (S.Demonic:IsAvailable() and Player:BuffP(S.MetamorphosisBuff)) then
      if HR.Cast(S.Metamorphosis, Settings.Havoc.OffGCDasOffGCD.Metamorphosis) then return "Cast Metamorphosis (Demonic)"; end
    end
    -- nemesis,if=!raid_event.adds.exists
    if S.Nemesis:IsCastable() then
      if HR.Cast(S.Nemesis, Settings.Havoc.OffGCDasOffGCD.Nemesis) then return "Cast Nemesis"; end
    end
    -- potion,if=buff.metamorphosis.remains>25|target.time_to_die<60
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (Player:BuffRemainsP(S.MetamorphosisBuff) > 25 or Target:TimeToDie() < 60) then
      if HR.CastSuggested(I.ProlongedPower) then return "Use Potion"; end
    end
  end

  local function CastFelRush()
    if Settings.Havoc.FelRushDisplayStyle == "Suggested" then
      return HR.CastSuggested(S.FelRush);
    elseif Settings.Havoc.FelRushDisplayStyle == "Cooldown" then
      if S.FelRush:TimeSinceLastDisplay() ~= 0 then
        return HR.Cast(S.FelRush, { true, false } );
      else
        return false;
      end
    end

    return HR.Cast(S.FelRush);
  end

  local function DarkSlash()
    if not IsInMeleeRange() then return; end

    -- dark_slash,if=fury>=80&(!variable.blade_dance|!cooldown.blade_dance.ready)
    if S.DarkSlash:IsCastable() and Player:Fury() >= 80
      and (not BladeDance() or (not S.BladeDance:IsReady() and not S.DeathSweep:IsReady())) then
      if HR.Cast(S.DarkSlash) then return "Cast Dark Slash"; end
    end
    -- annihilation,if=debuff.dark_slash.up
    if S.Annihilation:IsReady() and Target:DebuffP(S.DarkSlash) then
      if HR.Cast(S.Annihilation) then return "Cast Annihilation (Dark Slash)"; end
    end
    -- chaos_strike,if=debuff.dark_slash.up
    if S.ChaosStrike:IsReady() and Target:DebuffP(S.DarkSlash) then
      if HR.Cast(S.ChaosStrike) then return "Cast Chaos Strike (Dark Slash)"; end
    end
  end

  local function Demonic()
    local InMeleeRange = IsInMeleeRange()

    -- fel_barrage,if=active_enemies>desired_targets|raid_event.adds.in>30
    if S.FelBarrage:IsCastable(8, true) then
      if HR.Cast(S.FelBarrage) then return "Cast Fel Barrage"; end
    end
    -- death_sweep,if=variable.blade_dance
    if S.DeathSweep:IsReady(8, true) and BladeDance() then
      if HR.Cast(S.DeathSweep) then return "Cast Death Sweep"; end
    end
    -- blade_dance,if=variable.blade_dance&cooldown.eye_beam.remains>5&!cooldown.metamorphosis.ready
    if S.BladeDance:IsReady(8, true)
      and BladeDance() and S.EyeBeam:CooldownRemainsP() > 5 and not S.Metamorphosis:IsReady() then
      if HR.Cast(S.BladeDance) then return "Cast Blade Dance"; end
    end
    -- immolation_aura
    if S.ImmolationAura:IsCastable(8, true) then
      if HR.Cast(S.ImmolationAura) then return "Cast Immolation Aura"; end
    end
    -- felblade,if=fury<40|(buff.metamorphosis.down&fury.deficit>=40)
    if S.Felblade:IsCastable(S.Felblade)
      and (Player:Fury() < 40 or (not Player:BuffP(S.MetamorphosisBuff) and Player:FuryDeficit() >= 40)) then
      if HR.Cast(S.Felblade) then return "Cast Felblade"; end
    end
    -- eye_beam,if=(!talent.blind_fury.enabled|fury.deficit>=70)&(!buff.metamorphosis.extended_by_demonic|(set_bonus.tier21_4pc&buff.metamorphosis.remains>16))
    if S.EyeBeam:IsReady(20, true) and (not S.BlindFury:IsAvailable() or Player:FuryDeficit() >= 70)
      and (not IsMetaExtendedByDemonic() or (HL.Tier21_4Pc and Player:BuffRemainsP(S.MetamorphosisBuff) > 16)) then
      if HR.Cast(S.EyeBeam) then return "Cast Eye Beam"; end
    end
    -- annihilation,if=(talent.blind_fury.enabled|fury.deficit<30|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
    if InMeleeRange and S.Annihilation:IsReady()
      and (S.BlindFury:IsAvailable() or Player:FuryDeficit() < 30 or Player:BuffRemainsP(S.MetamorphosisBuff) < 5) and not PoolingForBladeDance() then
      if HR.Cast(S.Annihilation) then return "Cast Annihilation"; end
    end
    -- chaos_strike,if=(talent.blind_fury.enabled|fury.deficit<30)&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
    if InMeleeRange and S.ChaosStrike:IsReady()
      and (S.BlindFury:IsAvailable() or Player:FuryDeficit() < 30) and not PoolingForBladeDance() then
      if HR.Cast(S.ChaosStrike) then return "Cast Chaos Strike"; end
    end
    -- fel_rush,if=talent.demon_blades.enabled&!cooldown.eye_beam.ready&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastable(20, true) and S.DemonBlades:IsAvailable() and not S.EyeBeam:IsReady() then
      if CastFelRush() then return "Cast Fel Rush (Filler)"; end
    end
    -- demons_bite
    if InMeleeRange and S.DemonsBite:IsCastable() then
      if HR.Cast(S.DemonsBite) then return "Cast Demon's Bite"; end
    end
    -- throw_glaive,if=buff.out_of_range.up
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive) and not IsInMeleeRange() then
      if HR.Cast(S.ThrowGlaive) then return "Cast Throw Glave (OOR)"; end
    end
    -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
    if S.FelRush:IsCastable(20) and (not IsInMeleeRange() and not S.Momentum:IsAvailable()) then
      if CastFelRush() then return "Cast Fel Rush (OOR)"; end
    end
    -- throw_glaive,if=talent.demon_blades.enabled
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive) and S.DemonBlades:IsAvailable() then
      if HR.Cast(S.ThrowGlaive) then return "Cast Throw Glave (OOR)"; end
    end
  end

  local function Normal()
    local InMeleeRange = IsInMeleeRange()

    -- vengeful_retreat,if=talent.momentum.enabled&buff.prepared.down
    if S.VengefulRetreat:IsCastable("Melee", true) and S.Momentum:IsAvailable() and Player:BuffDownP(S.PreparedBuff) then
      if HR.Cast(S.VengefulRetreat) then return "Cast Vengeful Retreat (Momentum)"; end
    end
    -- fel_rush,if=(variable.waiting_for_momentum|talent.fel_mastery.enabled)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastable(20, true) and (WaitingForMomentum() or S.FelMastery:IsAvailable()) then
      if CastFelRush() then return "Cast Fel Rush (Momentum)"; end
    end
    -- fel_barrage,if=!variable.waiting_for_momentum&(active_enemies>desired_targets|raid_event.adds.in>30)
    if S.FelBarrage:IsCastable(8, true) and not WaitingForMomentum() then
      if HR.Cast(S.FelBarrage) then return "Cast Fel Barrage"; end
    end
    -- immolation_aura
    if S.ImmolationAura:IsCastable(8, true) then
      if HR.Cast(S.ImmolationAura) then return "Cast Immolation Aura"; end
    end
    -- eye_beam,if=active_enemies>1&(!raid_event.adds.exists|raid_event.adds.up)&!variable.waiting_for_momentum
    if S.EyeBeam:IsReady(20, true) and HR.AoEON() and Cache.EnemiesCount[CleaveRangeID] > 1 and not WaitingForMomentum() then
      if HR.Cast(S.EyeBeam) then return "Cast Eye Beam (AoE)"; end
    end
    -- death_sweep,if=variable.blade_dance
    if S.DeathSweep:IsReady(8, true) and BladeDance() then
      if HR.Cast(S.DeathSweep) then return "Cast Death Sweep"; end
    end
    -- blade_dance,if=variable.blade_dance
    if S.BladeDance:IsReady(8, true) and BladeDance() then
      if HR.Cast(S.BladeDance) then return "Cast Blade Dance"; end
    end
    -- felblade,if=fury.deficit>=40
    if S.Felblade:IsCastable(S.Felblade) and Player:FuryDeficit() >= 40 then
      if HR.Cast(S.Felblade) then return "Cast Felblade"; end
    end
    -- eye_beam,if=!talent.blind_fury.enabled&!variable.waiting_for_dark_slash&raid_event.adds.in>cooldown
    if S.EyeBeam:IsReady(20, true) and not S.BlindFury:IsAvailable() and not WaitingForDarkSlash() then
      if HR.Cast(S.EyeBeam) then return "Cast Eye Beam"; end
    end
    -- annihilation,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance&!variable.waiting_for_dark_slash
    if InMeleeRange and S.Annihilation:IsReady()
      and (S.DemonBlades:IsAvailable() or not WaitingForMomentum() or Player:FuryDeficit() < 30 or Player:BuffRemainsP(S.MetamorphosisBuff) < 5)
      and not PoolingForBladeDance() and not WaitingForDarkSlash() then
      if HR.Cast(S.Annihilation) then return "Cast Annihilation"; end
    end
    -- chaos_strike,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30)&!variable.pooling_for_meta&!variable.pooling_for_blade_dance&!variable.waiting_for_dark_slash
    if InMeleeRange and S.ChaosStrike:IsReady()
      and (S.DemonBlades:IsAvailable() or not WaitingForMomentum() or Player:FuryDeficit() < 30)
      and not PoolingForBladeDance() and not WaitingForDarkSlash() then
      if HR.Cast(S.ChaosStrike) then return "Cast Chaos Strike"; end
    end
    -- eye_beam,if=talent.blind_fury.enabled&raid_event.adds.in>cooldown
    if S.EyeBeam:IsReady(20, true) and S.BlindFury:IsAvailable() then
      if HR.Cast(S.EyeBeam) then return "Cast Eye Beam"; end
    end
    -- demons_bite
    if InMeleeRange and S.DemonsBite:IsCastable() then
      if HR.Cast(S.DemonsBite) then return "Cast Demon's Bite"; end
    end
    -- fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&talent.demon_blades.enabled
    if S.FelRush:IsCastable(20) and not S.Momentum:IsAvailable() and S.DemonBlades:IsAvailable() then
      if CastFelRush() then return "Cast Fel Rush (Filler)"; end
    end
    -- felblade,if=movement.distance>15|buff.out_of_range.up
    if S.Felblade:IsCastable(S.Felblade) and (not IsInMeleeRange()) then
      if HR.Cast(S.Felblade) then return "Cast Felblade (OOR)"; end
    end
    -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
    if S.FelRush:IsCastable(20) and (not IsInMeleeRange() and not S.Momentum:IsAvailable()) then
      if CastFelRush() then return "Cast Fel Rush (OOR)"; end
    end
    -- throw_glaive,if=talent.demon_blades.enabled
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive) and S.DemonBlades:IsAvailable() then
      if HR.Cast(S.ThrowGlaive) then return "Cast Throw Glaive (OOR)"; end
    end
  end

  -- Unit Update
  HL.GetEnemies(8, true); -- Blade Dance/Chaos Nova
  HL.GetEnemies(S.Disrupt, true); -- 20y, use for TG Bounce and Eye Beam
  HL.GetEnemies("Melee"); -- Melee
  Everyone.AoEToggleEnemiesUpdate();

  if Everyone.TargetIsValid() then
    -- Interrupts
    Everyone.Interrupt(20, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, StunInterrupts);

    -- call_action_list,name=cooldown,if=gcd.remains=0
    if HR.CDsON() then
      ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end

    -- pick_up_fragment,if=fury.deficit>=35
    -- TODO: Can't detect when orbs actually spawn, we could possibly show a suggested icon when we DON'T want to pick up souls so people can avoid moving?

    -- call_action_list,name=dark_slash,if=talent.dark_slash.enabled&(variable.waiting_for_dark_slash|debuff.dark_slash.up)
    if S.DarkSlash:IsAvailable() and (WaitingForDarkSlash() or Target:DebuffP(S.DarkSlash)) then
      ShouldReturn = DarkSlash(); if ShouldReturn then return ShouldReturn; end
    end

    -- run_action_list,name=demonic,if=talent.demonic.enabled
    -- run_action_list,name=normal
    if (S.Demonic:IsAvailable()) then
      ShouldReturn = Demonic();
    else
      ShouldReturn = Normal();
    end

    if ShouldReturn then
      return ShouldReturn;
    elseif IsInMeleeRange() and HR.Cast(S.PoolEnergy) then
      return "Pool for Fury";
    end
  end
end

HR.SetAPL(577, APL);

--- ======= SIMC =======
--- Last Update: 02/03/2018

--[[
# Executed before combat begins. Accepts non-harmful actions only.
actions.precombat=flask
actions.precombat+=/augmentation
actions.precombat+=/food
# Snapshot raid buffed stats before combat begins and pre-potting is done.
actions.precombat+=/snapshot_stats
actions.precombat+=/potion
actions.precombat+=/metamorphosis

# Executed every time the actor is available.
actions=auto_attack
actions+=/variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=(3-talent.trail_of_ruin.enabled)
actions+=/variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
actions+=/variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)
actions+=/variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
actions+=/variable,name=waiting_for_dark_slash,value=talent.dark_slash.enabled&!variable.pooling_for_blade_dance&!variable.pooling_for_meta&cooldown.dark_slash.up
actions+=/variable,name=waiting_for_momentum,value=talent.momentum.enabled&!buff.momentum.up
actions+=/disrupt
actions+=/call_action_list,name=cooldown,if=gcd.remains=0
actions+=/pick_up_fragment,if=fury.deficit>=35
actions+=/call_action_list,name=dark_slash,if=talent.dark_slash.enabled&(variable.waiting_for_dark_slash|debuff.dark_slash.up)
actions+=/run_action_list,name=demonic,if=talent.demonic.enabled
actions+=/run_action_list,name=normal

actions.cooldown=metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis)|target.time_to_die<25
actions.cooldown+=/metamorphosis,if=talent.demonic.enabled&buff.metamorphosis.up
actions.cooldown+=/nemesis,target_if=min:target.time_to_die,if=raid_event.adds.exists&debuff.nemesis.down&(active_enemies>desired_targets|raid_event.adds.in>60)
actions.cooldown+=/nemesis,if=!raid_event.adds.exists
actions.cooldown+=/potion,if=buff.metamorphosis.remains>25|target.time_to_die<60

actions.dark_slash=dark_slash,if=fury>=80&(!variable.blade_dance|!cooldown.blade_dance.ready)
actions.dark_slash+=/annihilation,if=debuff.dark_slash.up
actions.dark_slash+=/chaos_strike,if=debuff.dark_slash.up

actions.demonic=fel_barrage,if=active_enemies>desired_targets|raid_event.adds.in>30
actions.demonic+=/death_sweep,if=variable.blade_dance
actions.demonic+=/blade_dance,if=variable.blade_dance&cooldown.eye_beam.remains>5&!cooldown.metamorphosis.ready
actions.demonic+=/immolation_aura
actions.demonic+=/felblade,if=fury<40|(buff.metamorphosis.down&fury.deficit>=40)
actions.demonic+=/eye_beam,if=(!talent.blind_fury.enabled|fury.deficit>=70)&(!buff.metamorphosis.extended_by_demonic|(set_bonus.tier21_4pc&buff.metamorphosis.remains>16))
actions.demonic+=/annihilation,if=(talent.blind_fury.enabled|fury.deficit<30|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
actions.demonic+=/chaos_strike,if=(talent.blind_fury.enabled|fury.deficit<30)&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
actions.demonic+=/fel_rush,if=talent.demon_blades.enabled&!cooldown.eye_beam.ready&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
actions.demonic+=/demons_bite
actions.demonic+=/throw_glaive,if=buff.out_of_range.up
actions.demonic+=/fel_rush,if=movement.distance>15|buff.out_of_range.up
actions.demonic+=/vengeful_retreat,if=movement.distance>15
actions.demonic+=/throw_glaive,if=talent.demon_blades.enabled

actions.normal=vengeful_retreat,if=talent.momentum.enabled&buff.prepared.down
actions.normal+=/fel_rush,if=(variable.waiting_for_momentum|talent.fel_mastery.enabled)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
actions.normal+=/fel_barrage,if=!variable.waiting_for_momentum&(active_enemies>desired_targets|raid_event.adds.in>30)
actions.normal+=/immolation_aura
actions.normal+=/eye_beam,if=active_enemies>1&(!raid_event.adds.exists|raid_event.adds.up)&!variable.waiting_for_momentum
actions.normal+=/death_sweep,if=variable.blade_dance
actions.normal+=/blade_dance,if=variable.blade_dance
actions.normal+=/felblade,if=fury.deficit>=40
actions.normal+=/eye_beam,if=!talent.blind_fury.enabled&!variable.waiting_for_dark_slash&raid_event.adds.in>cooldown
actions.normal+=/annihilation,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance&!variable.waiting_for_dark_slash
actions.normal+=/chaos_strike,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30)&!variable.pooling_for_meta&!variable.pooling_for_blade_dance&!variable.waiting_for_dark_slash
actions.normal+=/eye_beam,if=talent.blind_fury.enabled&raid_event.adds.in>cooldown
actions.normal+=/demons_bite
actions.normal+=/fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&talent.demon_blades.enabled
actions.normal+=/felblade,if=movement.distance>15|buff.out_of_range.up
actions.normal+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
actions.normal+=/vengeful_retreat,if=movement.distance>15
actions.normal+=/throw_glaive,if=talent.demon_blades.enabled
]]
