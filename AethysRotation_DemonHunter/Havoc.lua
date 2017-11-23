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
  ConsumeMagic                  = Spell(183752),
  ChaosStrike                   = Spell(162794),
  ChaosNova                     = Spell(179057),
  DeathSweep                    = Spell(210152),
  DemonsBite                    = Spell(162243),
  EyeBeam                       = Spell(198013),
  FelRush                       = Spell(195072),
  Metamorphosis                 = Spell(191427),
  MetamorphosisBuff             = Spell(162264),
  ThrowGlaive                   = Spell(185123),
  VengefulRetreat               = Spell(198793),
  -- Talents
  BlindFury                     = Spell(203550),
  Bloodlet                      = Spell(206473),
  ChaosBlades                   = Spell(247938),
  ChaosCleave                   = Spell(206475),
  DemonBlades                   = Spell(203555),
  Demonic                       = Spell(213410),
  DemonicAppetite               = Spell(206478),
  DemonReborn                   = Spell(193897),
  FelBarrage                    = Spell(211053),
  Felblade                      = Spell(232893),
  FelEruption                   = Spell(211881),
  FelMastery                    = Spell(192939),
  FirstBlood                    = Spell(206416),
  MasterOfTheGlaive             = Spell(203556),
  Momentum                      = Spell(206476),
  MomentumBuff                  = Spell(208628),
  Nemesis                       = Spell(206491),
  Prepared                      = Spell(203551),
  PreparedBuff                  = Spell(203650),
  -- Artifact
  FuryOfTheIllidari             = Spell(201467),
  -- Misc
  PoolEnergy                    = Spell(9999000010),
};
local S = Spell.DemonHunter.Havoc;

-- Items
if not Item.DemonHunter then Item.DemonHunter = {}; end
Item.DemonHunter.Havoc = {
  -- Legendaries
  AngerOfTheHalfGiants          = Item(137038, {11, 12}),
  DelusionsOfGrandeur           = Item(144279, {3}),
  -- Trinkets
  ConvergenceofFates            = Item(140806, {13, 14}),
  -- Potion
  ProlongedPower                = Item(142117),
};
local I = Item.DemonHunter.Havoc;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local CleaveRangeID = tostring(S.ConsumeMagic:ID()); -- 20y range

-- GUI Settings
local Everyone = AR.Commons.Everyone;
local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.DemonHunter.Commons,
  Havoc = AR.GUISettings.APL.DemonHunter.Havoc
};

-- Interrupts List
local StunInterrupts = {
  {S.ArcaneTorrent, "Cast Arcane Torrent (Interrupt)", function () return true; end},
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
  -- TODO: Implement event tracking
  if not Player:BuffP(S.MetamorphosisBuff) then
    return false;
  end

  return false;
end

local function MetamorphosisCooldownAdjusted()
  -- TODO: Make this better by sampling the Fury expenses over time instead of approximating
  if I.ConvergenceofFates:IsEquipped() and I.DelusionsOfGrandeur:IsEquipped() then
    return S.Metamorphosis:CooldownRemainsP() * 0.56;
  elseif I.ConvergenceofFates:IsEquipped() then
    return S.Metamorphosis:CooldownRemainsP() * 0.78;
  elseif I.DelusionsOfGrandeur:IsEquipped() then
    return S.Metamorphosis:CooldownRemainsP() * 0.67;
  end

  return S.Metamorphosis:CooldownRemainsP()
end

-- Variables
-- variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
local function WaitingForNemesis()
  return not (not S.Nemesis:IsAvailable() or S.Nemesis:IsReady() or S.Nemesis:CooldownRemainsP() > Target:TimeToDie() or S.Nemesis:CooldownRemainsP() > 60);
end
-- variable,name=waiting_for_chaos_blades,value=!(!talent.chaos_blades.enabled|cooldown.chaos_blades.ready|cooldown.chaos_blades.remains>target.time_to_die|cooldown.chaos_blades.remains>60)
local function WaitingForChaosBlades()
  return not (not S.ChaosBlades:IsAvailable() or S.ChaosBlades:IsReady() or S.ChaosBlades:CooldownRemainsP() > Target:TimeToDie()
    or S.ChaosBlades:CooldownRemainsP() > 60);
end
-- variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)&(!variable.waiting_for_chaos_blades|cooldown.chaos_blades.remains<6)
local function PoolingForMeta()
  if not AR.CDsON() then
    return false;
  end;
  return not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemainsP() < 6 and Player:FuryDeficit() > 30
    and (not WaitingForNemesis() or S.Nemesis:CooldownRemainsP() < 10) and (not WaitingForChaosBlades() or S.ChaosBlades:CooldownRemainsP() < 6);
end
-- variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*3)
local function BladeDance()
  return S.FirstBlood:IsAvailable() or AC.Tier20_4Pc or (AR.AoEON() and Cache.EnemiesCount[8] >= 3 + (S.ChaosCleave:IsAvailable() and 3 or 0));
end
-- variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
local function PoolingForBladeDance()
  return BladeDance() and (Player:Fury() < 75 - (S.FirstBlood:IsAvailable() and 20 or 0));
end
-- variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd
local function PoolingForChaosStrike()
  return false;
end

-- Main APL
local function APL()
  local function Cooldown()
    -- Locals for tracking if we should display these suggestions together
    local MetamorphosisSuggested, ChaosBladesSuggested;

    -- metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis|variable.waiting_for_chaos_blades)|target.time_to_die<25
    if S.Metamorphosis:IsCastable()
      and (not (S.Demonic:IsAvailable() or PoolingForMeta() or WaitingForNemesis() or WaitingForChaosBlades()) or Target:TimeToDie() < 25) then
      if AR.Cast(S.Metamorphosis, Settings.Havoc.OffGCDasOffGCD.Metamorphosis) then return ""; end
      MetamorphosisSuggested = true;
    end
    -- metamorphosis,if=talent.demonic.enabled&buff.metamorphosis.up&fury<40
    if S.Metamorphosis:IsCastable() and (S.Demonic:IsAvailable() and Player:BuffP(S.MetamorphosisBuff) and Player:Fury() < 40) then
      if AR.Cast(S.Metamorphosis, Settings.Havoc.OffGCDasOffGCD.Metamorphosis) then return ""; end
      MetamorphosisSuggested = true;
    end
    -- chaos_blades,if=buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains>60|target.time_to_die<=duration
    if S.ChaosBlades:IsCastable()
      and (Player:BuffP(S.MetamorphosisBuff) or MetamorphosisSuggested or MetamorphosisCooldownAdjusted() > 60 or Target:TimeToDie() <= 18) then
      if AR.Cast(S.ChaosBlades, Settings.Havoc.OffGCDasOffGCD.ChaosBlades) then return ""; end
      ChaosBladesSuggested = true;
    end
    -- nemesis,if=!raid_event.adds.exists&(buff.chaos_blades.up|buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains<20|target.time_to_die<=60)
    if S.Nemesis:IsCastable() and ((Player:BuffP(S.ChaosBlades) or ChaosBladesSuggested
      or Player:BuffP(S.MetamorphosisBuff) or MetamorphosisSuggested or MetamorphosisCooldownAdjusted() < 20 or Target:TimeToDie() <= 60)) then
      if AR.Cast(S.Nemesis, Settings.Havoc.OffGCDasOffGCD.Nemesis) then return ""; end
    end
    -- potion,if=buff.metamorphosis.remains>25|target.time_to_die<30
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (Player:BuffRemainsP(S.MetamorphosisBuff) > 25 or Target:TimeToDie() < 30) then
      if AR.CastSuggested(I.ProlongedPower) then return ""; end
    end
  end

  local function CastFelRush()
    if Settings.Havoc.FelRushDisplayStyle == "Suggested" then
      return AR.CastSuggested(S.FelRush);
    elseif Settings.Havoc.FelRushDisplayStyle == "Cooldown" then
      if S.FelRush:TimeSinceLastDisplay() ~= 0 then
        return AR.Cast(S.FelRush, { true, false } );
      else
        return false;
      end
    end

    return AR.Cast(S.FelRush);
  end

  local function Demonic()
    local InMeleeRange = IsInMeleeRange()

    -- vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
    if S.VengefulRetreat:IsCastable("Melee", true)
      and ((S.Prepared:IsAvailable() or S.Momentum:IsAvailable()) and Player:BuffDownP(S.PreparedBuff) and Player:BuffDownP(S.MomentumBuff)) then
      if AR.Cast(S.VengefulRetreat) then return ""; end
    end
    -- fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastable(20, true) and ((S.Momentum:IsAvailable() or S.FelMastery:IsAvailable())
      and (not S.Momentum:IsAvailable() or (S.FelRush:ChargesP() == 2 or S.VengefulRetreat:CooldownRemainsP() > 4) and Player:BuffDownP(S.MomentumBuff))) then
      if CastFelRush() then return ""; end
    end
    -- throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive)
      and (S.Bloodlet:IsAvailable() and (not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff)) and S.ThrowGlaive:ChargesP() == 2) then
      if AR.Cast(S.ThrowGlaive) then return ""; end
    end
    -- death_sweep,if=variable.blade_dance
    if S.DeathSweep:IsReady(8, true) and (BladeDance()) then
      if AR.Cast(S.DeathSweep) then return ""; end
    end
    -- fel_eruption
    if S.FelEruption:IsReady(S.FelEruption) then
      if AR.Cast(S.FelEruption) then return ""; end
    end
    -- fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up))
    if S.FuryOfTheIllidari:IsCastable(6, true)
      and ((AR.AoEON() and Cache.EnemiesCount[6] > 1) or (not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
      if AR.Cast(S.FuryOfTheIllidari) then return ""; end
    end
    -- blade_dance,if=variable.blade_dance&cooldown.eye_beam.remains>5&!cooldown.metamorphosis.ready
    if S.BladeDance:IsReady(8, true)
      and (BladeDance() and S.EyeBeam:CooldownRemainsP() > 5 and not S.Metamorphosis:IsReady()) then
      if AR.Cast(S.BladeDance) then return ""; end
    end
    -- throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive) and (S.Bloodlet:IsAvailable() and (AR.AoEON() and Cache.EnemiesCount[CleaveRangeID] >= 2) and
      (not S.MasterofTheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
      if AR.Cast(S.ThrowGlaive) then return ""; end
    end
    -- felblade,if=fury.deficit>=30
    if S.Felblade:IsCastable(S.Felblade) and (Player:FuryDeficit() >= 30) then
      if AR.Cast(S.Felblade) then return ""; end
    end
    -- eye_beam,if=spell_targets.eye_beam_tick>desired_targets|!buff.metamorphosis.extended_by_demonic|(set_bonus.tier21_4pc&buff.metamorphosis.remains>8)
    if S.EyeBeam:IsReady(20, true) and ((AR.AoEON() and Cache.EnemiesCount[CleaveRangeID] > 1)
      or not IsMetaExtendedByDemonic() or (AC.Tier21_4Pc and Player:BuffRemainsP(S.MetamorphosisBuff) > 8)) then
      if AR.Cast(S.EyeBeam) then return ""; end
    end
    -- annihilation,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
    if InMeleeRange and S.Annihilation:IsReady()
      and ((not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff) or Player:FuryDeficit() < 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0)
        or Player:BuffRemainsP(S.MetamorphosisBuff) < 5) and not PoolingForBladeDance()) then
      if AR.Cast(S.Annihilation) then return ""; end
    end
    -- throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive)
      and (S.Bloodlet:IsAvailable() and (not S.MasterofTheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
      if AR.Cast(S.ThrowGlaive) then return ""; end
    end
    -- chaos_strike,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
    if InMeleeRange and S.ChaosStrike:IsReady()
      and ((not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff) or Player:FuryDeficit() < 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0))
        and not PoolingForChaosStrike() and not PoolingForMeta() and not PoolingForBladeDance()) then
      if AR.Cast(S.ChaosStrike) then return ""; end
    end
    -- fel_rush,if=!talent.momentum.enabled&(buff.metamorphosis.down|talent.demon_blades.enabled)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastable(20, true) and (not S.Momentum:IsAvailable() and (Player:BuffDownP(S.MetamorphosisBuff) or S.DemonBlades:IsAvailable())) then
      if CastFelRush() then return ""; end
    end
    -- demons_bite
    if InMeleeRange and S.DemonsBite:IsCastable() then
      if AR.Cast(S.DemonsBite) then return ""; end
    end
    -- throw_glaive,if=buff.out_of_range.up|!talent.bloodlet.enabled
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive) and (not IsInMeleeRange() or not S.Bloodlet:IsAvailable()) then
      if AR.Cast(S.ThrowGlaive) then return ""; end
    end
    -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
    if S.FelRush:IsCastable(20) and (not IsInMeleeRange() and not S.Momentum:IsAvailable()) then
      if CastFelRush() then return ""; end
    end
  end

  local function Normal()
    local InMeleeRange = IsInMeleeRange()

    -- vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
    if S.VengefulRetreat:IsCastable("Melee", true)
      and ((S.Prepared:IsAvailable() or S.Momentum:IsAvailable()) and Player:BuffDownP(S.PreparedBuff) and Player:BuffDownP(S.MomentumBuff)) then
      if AR.Cast(S.VengefulRetreat) then return "VR Momo"; end
    end
    -- fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(!talent.fel_mastery.enabled|fury.deficit>=25)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastable(20, true) and ((S.Momentum:IsAvailable() or S.FelMastery:IsAvailable())
      and (not S.Momentum:IsAvailable() or (S.FelRush:ChargesP() == 2 or S.VengefulRetreat:CooldownRemainsP() > 4) and Player:BuffDownP(S.MomentumBuff))
      and (not S.FelMastery:IsAvailable() or Player:FuryDeficit() >= 25)) then
      if CastFelRush() then return "FR Momo"; end
    end
    -- fel_barrage,if=(buff.momentum.up|!talent.momentum.enabled)&(active_enemies>desired_targets|raid_event.adds.in>30)
    if S.FelBarrage:IsCastable(S.FelBarrage) and ((Player:BuffP(S.MomentumBuff) or not S.Momentum:IsAvailable())) then
      if AR.Cast(S.FelBarrage) then return "FBarr"; end
    end
    -- throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive)
      and (S.Bloodlet:IsAvailable() and (not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff)) and S.ThrowGlaive:ChargesP() == 2) then
      if AR.Cast(S.ThrowGlaive) then return "TG Capped"; end
    end
    -- felblade,if=fury<15&(cooldown.death_sweep.remains<2*gcd|cooldown.blade_dance.remains<2*gcd)
    if S.Felblade:IsCastable(S.Felblade)
      and (Player:Fury() < 15 and (S.DeathSweep:CooldownRemainsP() < 2 * Player:GCD() or S.BladeDance:CooldownRemainsP() < 2 * Player:GCD())) then
      if AR.Cast(S.Felblade) then return "FB Low Fury"; end
    end
    -- death_sweep,if=variable.blade_dance
    if S.DeathSweep:IsReady(8, true) and (BladeDance()) then
      if AR.Cast(S.DeathSweep) then return "DS"; end
    end
    -- fel_rush,if=charges=2&!talent.momentum.enabled&!talent.fel_mastery.enabled&!buff.metamorphosis.up
    if S.FelRush:IsCastable(20, true)
      and (S.FelRush:ChargesP() == 2 and not S.Momentum:IsAvailable() and not S.FelMastery:IsAvailable() and not Player:BuffP(S.MetamorphosisBuff)) then
      if CastFelRush() then return "FR Capped"; end
    end
    -- fel_eruption
    if S.FelEruption:IsReady(S.FelEruption) then
      if AR.Cast(S.FelEruption) then return "FE"; end
    end
    -- fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up)&(!talent.chaos_blades.enabled|buff.chaos_blades.up|cooldown.chaos_blades.remains>30|target.time_to_die<cooldown.chaos_blades.remains))
    if S.FuryOfTheIllidari:IsCastable(6, true) and ((AR.AoEON() and Cache.EnemiesCount[6] > 1) or ((not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))
      and (not S.ChaosBlades:IsAvailable() or Player:BuffP(S.ChaosBlades) or S.ChaosBlades:CooldownRemainsP() > 30
      or Target:TimeToDie() < S.ChaosBlades:CooldownRemainsP()))) then
      if AR.Cast(S.FuryOfTheIllidari) then return "FotI"; end
    end
    -- blade_dance,if=variable.blade_dance
    if S.BladeDance:IsReady(8, true) and (BladeDance()) then
      if AR.Cast(S.BladeDance) then return "BD"; end
    end
    -- throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
    if AR.AoEON() and S.ThrowGlaive:IsCastable(S.ThrowGlaive) and (S.Bloodlet:IsAvailable() and Cache.EnemiesCount[CleaveRangeID] >= 2
      and (not S.MasterofTheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
      if AR.Cast(S.ThrowGlaive) then return "TG"; end
    end
    -- felblade,if=fury.deficit>=30+buff.prepared.up*8
    if S.Felblade:IsCastable(S.Felblade) and (Player:FuryDeficit() >= 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0)) then
      if AR.Cast(S.Felblade) then return "FB"; end
    end
    -- eye_beam,if=spell_targets.eye_beam_tick>desired_targets|(spell_targets.eye_beam_tick>=3&raid_event.adds.in>cooldown)|(talent.blind_fury.enabled&fury.deficit>=35)|set_bonus.tier21_2pc
    if S.EyeBeam:IsReady(20, true)
      and ((AR.AoEON() and Cache.EnemiesCount[CleaveRangeID] > 1) or (S.BlindFury:IsAvailable() and Player:FuryDeficit() >= 35) or AC.Tier21_2Pc) then
      if AR.Cast(S.EyeBeam) then return "EB"; end
    end
    -- annihilation,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
    if InMeleeRange and S.Annihilation:IsReady()
      and ((S.DemonBlades:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff)
        or Player:FuryDeficit() < 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0) or Player:BuffRemainsP(S.MetamorphosisBuff) < 5)
      and not PoolingForBladeDance()) then
      if AR.Cast(S.Annihilation) then return "AN"; end
    end
    -- throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive)
      and (S.Bloodlet:IsAvailable() and (not S.MasterofTheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
      if AR.Cast(S.ThrowGlaive) then return "TG Bloodlet"; end
    end
    -- throw_glaive,if=!talent.bloodlet.enabled&buff.metamorphosis.down&spell_targets>=3
    if AR.AoEON() and S.ThrowGlaive:IsCastable(S.ThrowGlaive)
      and (not S.Bloodlet:IsAvailable() and Player:BuffDownP(S.MetamorphosisBuff) and Cache.EnemiesCount[CleaveRangeID] >= 3) then
      if AR.Cast(S.ThrowGlaive) then return "TG Cleave"; end
    end
    -- chaos_strike,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
    if InMeleeRange and S.ChaosStrike:IsReady()
      and ((S.DemonBlades:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff)
        or Player:FuryDeficit() < 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0))
      and not PoolingForChaosStrike() and not PoolingForMeta() and not PoolingForBladeDance()) then
      if AR.Cast(S.ChaosStrike) then return "CS"; end
    end
    -- fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&(talent.demon_blades.enabled|buff.metamorphosis.down)
    if S.FelRush:IsCastable(20, true) and (not S.Momentum:IsAvailable() and (S.DemonBlades:IsAvailable() or Player:BuffDownP(S.MetamorphosisBuff))) then
      if CastFelRush() then return "FR Filler"; end
    end
    -- demons_bite
    if InMeleeRange and S.DemonsBite:IsCastable() then
      if AR.Cast(S.DemonsBite) then return "DB"; end
    end
    -- throw_glaive,if=buff.out_of_range.up
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive) and (not IsInMeleeRange()) then
      if AR.Cast(S.ThrowGlaive) then return "TG OOR"; end
    end
    -- felblade,if=movement.distance>15|buff.out_of_range.up
    if S.Felblade:IsCastable(S.Felblade) and (not IsInMeleeRange()) then
      if AR.Cast(S.Felblade) then return "FB OOR"; end
    end
    -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
    if S.FelRush:IsCastable(20) and (not IsInMeleeRange() and not S.Momentum:IsAvailable()) then
      if CastFelRush() then return "FR OOR"; end
    end
    -- throw_glaive,if=!talent.bloodlet.enabled
    if S.ThrowGlaive:IsCastable(S.ThrowGlaive) and (not S.Bloodlet:IsAvailable()) then
      if AR.Cast(S.ThrowGlaive) then return "TG Filler"; end
    end
  end

  -- Unit Update
  AC.GetEnemies(6, true); -- Fury of the Illidari
  AC.GetEnemies(8, true); -- Blade Dance/Chaos Nova
  AC.GetEnemies(S.ConsumeMagic, true); -- 20y, use for TG Bounce and Eye Beam
  AC.GetEnemies("Melee"); -- Melee
  Everyone.AoEToggleEnemiesUpdate();

  if Everyone.TargetIsValid() then
    -- Interrupts
    Everyone.Interrupt(20, S.ConsumeMagic, Settings.Commons.OffGCDasOffGCD.ConsumeMagic, StunInterrupts);

    -- call_action_list,name=cooldown,if=gcd.remains=0
    if AR.CDsON() then
      ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
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
    elseif IsInMeleeRange() and AR.Cast(S.PoolEnergy) then
      return "Pool for Fury";
    end
  end
end

AR.SetAPL(577, APL);

--- ======= SIMC =======
--- Last Update: 11/18/2017

--[[
# Executed before combat begins. Accepts non-harmful actions only.
actions.precombat=flask
actions.precombat+=/augmentation
actions.precombat+=/food
# Snapshot raid buffed stats before combat begins and pre-potting is done.
actions.precombat+=/snapshot_stats
actions.precombat+=/potion
actions.precombat+=/metamorphosis,if=!(talent.demon_reborn.enabled&talent.demonic.enabled)

# Executed every time the actor is available.
actions=auto_attack
actions+=/variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
actions+=/variable,name=waiting_for_chaos_blades,value=!(!talent.chaos_blades.enabled|cooldown.chaos_blades.ready|cooldown.chaos_blades.remains>target.time_to_die|cooldown.chaos_blades.remains>60)
# "Getting ready to use meta" conditions, this is used in a few places.
actions+=/variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)&(!variable.waiting_for_chaos_blades|cooldown.chaos_blades.remains<6)
# Blade Dance conditions. Always if First Blood is talented or the T20 4pc set bonus, otherwise at 6+ targets with Chaos Cleave or 3+ targets without.
actions+=/variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*3)
# Blade Dance pooling condition, so we don't spend too much fury on Chaos Strike when we need it soon.
actions+=/variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
# Chaos Strike pooling condition, so we don't spend too much fury when we need it for Chaos Cleave AoE
actions+=/variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd
actions+=/consume_magic
actions+=/call_action_list,name=cooldown,if=gcd.remains=0
actions+=/run_action_list,name=demonic,if=talent.demonic.enabled
actions+=/run_action_list,name=normal

# Use Metamorphosis when we are done pooling Fury and when we are not waiting for other cooldowns to sync.
actions.cooldown=metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis|variable.waiting_for_chaos_blades)|target.time_to_die<25
actions.cooldown+=/metamorphosis,if=talent.demonic.enabled&buff.metamorphosis.up&fury<40
# If adds are present, use Nemesis on the lowest HP add in order to get the Nemesis buff for AoE
actions.cooldown+=/nemesis,target_if=min:target.time_to_die,if=raid_event.adds.exists&debuff.nemesis.down&(active_enemies>desired_targets|raid_event.adds.in>60)
actions.cooldown+=/nemesis,if=!raid_event.adds.exists&(buff.chaos_blades.up|buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains<20|target.time_to_die<=60)
actions.cooldown+=/chaos_blades,if=buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains>60|target.time_to_die<=duration
actions.cooldown+=/potion,if=buff.metamorphosis.remains>25|target.time_to_die<30

# Specific APL for the Blind Fury+Demonic Appetite+Demonic build
actions.demonic=pick_up_fragment,if=fury.deficit>=35&(cooldown.eye_beam.remains>5|buff.metamorphosis.up)
# Vengeful Retreat backwards through the target to minimize downtime.
actions.demonic+=/vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
# Fel Rush for Momentum.
actions.demonic+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
actions.demonic+=/death_sweep,if=variable.blade_dance
actions.demonic+=/fel_eruption
actions.demonic+=/fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up))
actions.demonic+=/blade_dance,if=variable.blade_dance&cooldown.eye_beam.remains>5&!cooldown.metamorphosis.ready
actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
actions.demonic+=/felblade,if=fury.deficit>=30
actions.demonic+=/eye_beam,if=spell_targets.eye_beam_tick>desired_targets|!buff.metamorphosis.extended_by_demonic|(set_bonus.tier21_4pc&buff.metamorphosis.remains>8)
actions.demonic+=/annihilation,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
actions.demonic+=/chaos_strike,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
actions.demonic+=/fel_rush,if=!talent.momentum.enabled&(buff.metamorphosis.down|talent.demon_blades.enabled)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
actions.demonic+=/demons_bite
actions.demonic+=/throw_glaive,if=buff.out_of_range.up|!talent.bloodlet.enabled
actions.demonic+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
actions.demonic+=/vengeful_retreat,if=movement.distance>15

# General APL for Non-Demonic Builds
actions.normal=pick_up_fragment,if=talent.demonic_appetite.enabled&fury.deficit>=35
# Vengeful Retreat backwards through the target to minimize downtime.
actions.normal+=/vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
# Fel Rush for Momentum and for fury from Fel Mastery.
actions.normal+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(!talent.fel_mastery.enabled|fury.deficit>=25)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
# Use Fel Barrage at max charges, saving it for Momentum and adds if possible.
actions.normal+=/fel_barrage,if=(buff.momentum.up|!talent.momentum.enabled)&(active_enemies>desired_targets|raid_event.adds.in>30)
actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
actions.normal+=/felblade,if=fury<15&(cooldown.death_sweep.remains<2*gcd|cooldown.blade_dance.remains<2*gcd)
actions.normal+=/death_sweep,if=variable.blade_dance
actions.normal+=/fel_rush,if=charges=2&!talent.momentum.enabled&!talent.fel_mastery.enabled&!buff.metamorphosis.up
actions.normal+=/fel_eruption
actions.normal+=/fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up)&(!talent.chaos_blades.enabled|buff.chaos_blades.up|cooldown.chaos_blades.remains>30|target.time_to_die<cooldown.chaos_blades.remains))
actions.normal+=/blade_dance,if=variable.blade_dance
actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
actions.normal+=/felblade,if=fury.deficit>=30+buff.prepared.up*8
actions.normal+=/eye_beam,if=spell_targets.eye_beam_tick>desired_targets|(spell_targets.eye_beam_tick>=3&raid_event.adds.in>cooldown)|(talent.blind_fury.enabled&fury.deficit>=35)|set_bonus.tier21_2pc
actions.normal+=/annihilation,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled&buff.metamorphosis.down&spell_targets>=3
actions.normal+=/chaos_strike,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
actions.normal+=/fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&(talent.demon_blades.enabled|buff.metamorphosis.down)
actions.normal+=/demons_bite
actions.normal+=/throw_glaive,if=buff.out_of_range.up
actions.normal+=/felblade,if=movement.distance>15|buff.out_of_range.up
actions.normal+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
actions.normal+=/vengeful_retreat,if=movement.distance>15
actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled
]]