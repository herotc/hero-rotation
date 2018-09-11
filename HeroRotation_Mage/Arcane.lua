--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL     = HeroLib
local Cache  = HeroCache
local Unit   = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = HL.Spell
local Item   = HL.Item
-- HeroRotation
local HR     = HeroRotation

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Mage then Spell.Mage = {} end
Spell.Mage.Arcane = {
  ArcaneIntellectBuff                   = Spell(1459),
  ArcaneIntellect                       = Spell(1459),
  SummonArcaneFamiliarBuff              = Spell(210126),
  SummonArcaneFamiliar                  = Spell(205022),
  BrainStorm                            = Spell(273326),
  RuneofPowerBuff                       = Spell(116014),
  RuneofPower                           = Spell(116011),
  MirrorImage                           = Spell(55342),
  ArcaneBlast                           = Spell(30451),
  Evocation                             = Spell(12051),
  ArcanePowerBuff                       = Spell(12042),
  ArcanePower                           = Spell(12042),
  ChargedUp                             = Spell(205032),
  ArcaneChargeBuff                      = Spell(36032),
  NetherTempest                         = Spell(114923),
  NetherTempestDebuff                   = Spell(114923),
  RuleofThreesBuff                      = Spell(264774),
  Overpowered                           = Spell(155147),
  LightsJudgment                        = Spell(255647),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  PresenceofMind                        = Spell(205025),
  PresenceofMindBuff                    = Spell(205025),
  BerserkingBuff                        = Spell(26297),
  BloodFuryBuff                         = Spell(20572),
  ArcaneOrb                             = Spell(153626),
  Resonance                             = Spell(205028),
  ArcaneBarrage                         = Spell(44425),
  ArcaneExplosion                       = Spell(1449),
  ArcaneMissiles                        = Spell(5143),
  ClearcastingBuff                      = Spell(263725),
  Amplification                         = Spell(236628),
  ArcanePummeling                       = Spell(270669),
  Supernova                             = Spell(157980),
  Shimmer                               = Spell(212653),
  Blink                                 = Spell(1953)
};
local S = Spell.Mage.Arcane;

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Arcane = {
  DeadlyGrace                      = Item(127843)
};
local I = Item.Mage.Arcane;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Arcane = HR.GUISettings.APL.Mage.Arcane
};

-- Variables
local VarBurnPhase = 0;
local VarBurnPhaseStart = 0;
local VarBurnPhaseDuration = 0;
local VarConserveMana = 0;
local VarBsRotation = 0;
local VarTotalBurns = 0;
local VarAverageBurnLength = 0;

local EnemyRanges = {40, 10}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function PresenceOfMindMax ()
  return 2
end

local function ArcaneMissilesProcMax ()
  return 3
end

local VarBurnPhaseEnd = 0

local function StartBurnPhase ()
  VarBurnPhase = 1
  VarBurnPhaseStart = HL.GetTime()
end

local function StopBurnPhase ()
  VarBurnPhase = 0
  VarBurnPhaseEnd = HL.GetTime()
  VarBurnPhaseDuration = VarBurnPhaseEnd - VarBurnPhaseStart
  VarAverageBurnLength = (VarAverageBurnLength * VarTotalBurns - VarAverageBurnLength + (VarBurnPhaseDuration)) / VarTotalBurns
end

function Player:ArcaneChargesP()
    return math.min(self:ArcaneCharges() + num(self:IsCasting(S.ArcaneBlast)),4)
end
--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Burn, Conserve, Movement
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- arcane_intellect
    if S.ArcaneIntellect:IsCastableP() and Player:BuffDownP(S.ArcaneIntellectBuff, true) then
      if HR.Cast(S.ArcaneIntellect) then return ""; end
    end
    -- summon_arcane_familiar
    if S.SummonArcaneFamiliar:IsCastableP() and Player:BuffDownP(S.SummonArcaneFamiliarBuff) then
      if HR.Cast(S.SummonArcaneFamiliar) then return ""; end
    end
    -- variable,name=conserve_mana,op=set,value=60
    if (true) then
      VarConserveMana = 60
    end
    -- variable,name=bs_rotation,op=set,value=1,if=azerite.brain_storm.rank>=2&talent.rune_of_power.enabled
    if (S.BrainStorm:AzeriteRank() >= 2 and S.RuneofPower:IsAvailable()) then
      VarBsRotation = 1
    end
    -- snapshot_stats
    -- mirror_image
    if S.MirrorImage:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.MirrorImage) then return ""; end
    end
    -- potion
    if I.DeadlyGrace:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.DeadlyGrace) then return ""; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsReadyP() then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
  end
  Burn = function()
    -- variable,name=total_burns,op=add,value=1,if=!burn_phase
    if (not bool(VarBurnPhase)) then
      VarTotalBurns = VarTotalBurns + 1
    end
    -- start_burn_phase,if=!burn_phase
    if (not bool(VarBurnPhase)) then
      StartBurnPhase()
    end
    -- if we're evocating then stop if we have enough mana
    if (bool(VarBurnPhase)) and (Player:IsChanneling(S.Evocation) and (Player:ManaPercentage() < 85)) then
      if HR.Cast(S.Evocation) then return "Burn - Keep Evocating"; end
    end
    -- stop_burn_phase,if=burn_phase&variable.bs_rotation=0&prev_gcd.1.evocation&target.time_to_die>variable.average_burn_length&burn_phase_duration>0
    if (bool(VarBurnPhase) and VarBsRotation == 0 and Player:PrevGCDP(1, S.Evocation) and Target:TimeToDie() > VarAverageBurnLength and VarBurnPhaseDuration > 0) then
      StopBurnPhase()
    end
    -- stop_burn_phase,if=burn_phase&variable.bs_rotation=1&buff.arcane_power.down&cooldown.arcane_power.remains>0&buff.arcane_power.down&target.time_to_die>variable.average_burn_length&burn_phase_duration>0
    if (bool(VarBurnPhase) and VarBsRotation == 1 and Player:BuffDownP(S.ArcanePowerBuff) and S.ArcanePower:CooldownRemainsP() > 0 and Player:BuffDownP(S.ArcanePowerBuff) and Target:TimeToDie() > VarAverageBurnLength and VarBurnPhaseDuration > 0) then
      StopBurnPhase()
    end
    -- charged_up,if=buff.arcane_charge.stack<=1
    if S.ChargedUp:IsCastableP() and (Player:ArcaneChargesP() <= 1) then
      if HR.Cast(S.ChargedUp) then return ""; end
    end
    -- rune_of_power,if=variable.bs_rotation=1&!buff.arcane_power.up&mana.pct>=50&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)&(full_recharge_time<=execute_time|full_recharge_time<=cooldown.arcane_power.remains|target.time_to_die<=cooldown.arcane_power.remains)
    if S.RuneofPower:IsCastableP() and (VarBsRotation == 1 and not Player:BuffP(S.ArcanePowerBuff) and Player:ManaPercentage() >= 50 and (Player:ArcaneChargesP() == Player:ArcaneChargesMax()) and (S.RuneofPower:FullRechargeTimeP() <= S.RuneofPower:ExecuteTime() or S.RuneofPower:FullRechargeTimeP() <= S.ArcanePower:CooldownRemainsP() or Target:TimeToDie() <= S.ArcanePower:CooldownRemainsP())) then
      if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneofPower) then return "ROP Burn (BS)"; end
    end
    -- arcane_blast,if=variable.bs_rotation=1&(cooldown.evocation.remains>action.arcane_blast.execute_time&cooldown.evocation.remains<=variable.average_burn_length|cooldown.evocation.remains=0)&!prev_gcd.1.evocation
    if S.ArcaneBlast:IsReadyP() and (VarBsRotation == 1 and (S.Evocation:CooldownRemainsP() > S.ArcaneBlast:ExecuteTime() and S.Evocation:CooldownRemainsP() <= VarAverageBurnLength or S.Evocation:CooldownRemainsP() == 0) and not Player:PrevGCDP(1, S.Evocation)) then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- evocation,if=variable.bs_rotation=1
    if S.Evocation:IsCastableP() and (VarBsRotation == 1) then
      if HR.Cast(S.Evocation) then return ""; end
    end
    -- mirror_image
    if S.MirrorImage:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.MirrorImage) then return ""; end
    end
    -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
    if S.NetherTempest:IsCastableP() and ((Target:DebuffRefreshableCP(S.NetherTempestDebuff) or not Target:DebuffP(S.NetherTempestDebuff)) and Player:ArcaneChargesP() == Player:ArcaneChargesMax() and Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.NetherTempest) then return ""; end
    end
    -- arcane_blast,if=buff.rule_of_threes.up&talent.overpowered.enabled
    if S.ArcaneBlast:IsReadyP() and (Player:BuffP(S.RuleofThreesBuff) and S.Overpowered:IsAvailable()) then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- lights_judgment,if=buff.arcane_power.down
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.LightsJudgment) then return ""; end
    end
    -- rune_of_power,if=!buff.arcane_power.up&(mana.pct>=50|cooldown.arcane_power.remains=0)&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
    if S.RuneofPower:IsCastableP() and (not Player:BuffP(S.ArcanePowerBuff) and (Player:ManaPercentage() >= 50 or S.ArcanePower:CooldownRemainsP() == 0) and (Player:ArcaneChargesP() == Player:ArcaneChargesMax())) then
      if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneofPower) then return "ROP Burn"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- arcane_power
    if S.ArcanePower:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return ""; end
    end
    -- use_items,if=buff.arcane_power.up|target.time_to_die<cooldown.arcane_power.remains
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- presence_of_mind,if=buff.rune_of_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time|buff.arcane_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
    if S.PresenceofMind:IsCastableP() and HR.CDsON() and (Player:BuffRemainsP(S.RuneofPowerBuff) <= PresenceOfMindMax() * S.ArcaneBlast:ExecuteTime() or Player:BuffRemainsP(S.ArcanePowerBuff) <= PresenceOfMindMax() * S.ArcaneBlast:ExecuteTime()) then
      if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return ""; end
    end
    -- potion,if=buff.arcane_power.up&(buff.berserking.up|buff.blood_fury.up|!(race.troll|race.orc))
    if I.DeadlyGrace:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.ArcanePowerBuff) and (Player:BuffP(S.BerserkingBuff) or Player:BuffP(S.BloodFuryBuff) or not (Player:IsRace("Troll") or Player:IsRace("Orc")))) then
      if HR.CastSuggested(I.DeadlyGrace) then return ""; end
    end
    -- arcane_orb,if=buff.arcane_charge.stack=0|(active_enemies<3|(active_enemies<2&talent.resonance.enabled))
    if S.ArcaneOrb:IsCastableP() and (Player:ArcaneChargesP() == 0 or (Cache.EnemiesCount[40] < 3 or (Cache.EnemiesCount[40] < 2 and S.Resonance:IsAvailable()))) then
      if HR.Cast(S.ArcaneOrb) then return ""; end
    end
    -- arcane_barrage,if=active_enemies>=3&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
    if S.ArcaneBarrage:IsCastableP() and (Cache.EnemiesCount[40] >= 3 and (Player:ArcaneChargesP() == Player:ArcaneChargesMax())) then
      if HR.Cast(S.ArcaneBarrage) then return ""; end
    end
    -- arcane_explosion,if=active_enemies>=3
    if S.ArcaneExplosion:IsCastableP() and (Cache.EnemiesCount[10] >= 3) then
      if HR.Cast(S.ArcaneExplosion) then return ""; end
    end
    -- arcane_missiles,if=buff.clearcasting.react&active_enemies<3&(talent.amplification.enabled|(!talent.overpowered.enabled&azerite.arcane_pummeling.rank>=2)|buff.arcane_power.down),chain=1
    if S.ArcaneMissiles:IsCastableP() and (bool(Player:BuffStackP(S.ClearcastingBuff)) and Cache.EnemiesCount[40] < 3 and (S.Amplification:IsAvailable() or (not S.Overpowered:IsAvailable() and S.ArcanePummeling:AzeriteRank() >= 2) or Player:BuffDownP(S.ArcanePowerBuff))) then
      if HR.Cast(S.ArcaneMissiles) then return ""; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsReadyP() then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- variable,name=average_burn_length,op=set,value=(variable.average_burn_length*variable.total_burns-variable.average_burn_length+(burn_phase_duration))%variable.total_burns
    if (true) then
      VarAverageBurnLength = (VarAverageBurnLength * VarTotalBurns - VarAverageBurnLength + (VarBurnPhaseDuration)) / VarTotalBurns
    end
    -- evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
    if S.Evocation:IsCastableP() then
      if HR.Cast(S.Evocation) then return ""; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsCastableP() then
      if HR.Cast(S.ArcaneBarrage) then return ""; end
    end
  end
  Conserve = function()
    -- mirror_image
    if S.MirrorImage:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.MirrorImage) then return ""; end
    end
    -- charged_up,if=buff.arcane_charge.stack=0
    if S.ChargedUp:IsCastableP() and (Player:ArcaneChargesP() == 0) then
      if HR.Cast(S.ChargedUp) then return ""; end
    end
    -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
    if S.NetherTempest:IsCastableP() and ((Target:DebuffRefreshableCP(S.NetherTempestDebuff) or not Target:DebuffP(S.NetherTempestDebuff)) and Player:ArcaneChargesP() == Player:ArcaneChargesMax() and Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.NetherTempest) then return ""; end
    end
    -- arcane_orb,if=buff.arcane_charge.stack<=2&(cooldown.arcane_power.remains>10|active_enemies<=2)
    if S.ArcaneOrb:IsCastableP() and (Player:ArcaneChargesP() <= 2 and (S.ArcanePower:CooldownRemainsP() > 10 or Cache.EnemiesCount[40] <= 2)) then
      if HR.Cast(S.ArcaneOrb) then return ""; end
    end
    -- arcane_blast,if=buff.rule_of_threes.up&buff.arcane_charge.stack>3
    if S.ArcaneBlast:IsReadyP() and (Player:BuffP(S.RuleofThreesBuff) and Player:ArcaneChargesP() > 3) then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- rune_of_power,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&(full_recharge_time<=execute_time|full_recharge_time<=cooldown.arcane_power.remains|target.time_to_die<=cooldown.arcane_power.remains)
    if S.RuneofPower:IsCastableP() and (Player:ArcaneChargesP() == Player:ArcaneChargesMax() and (S.RuneofPower:FullRechargeTimeP() <= S.RuneofPower:ExecuteTime() or S.RuneofPower:FullRechargeTimeP() <= S.ArcanePower:CooldownRemainsP() or Target:TimeToDie() <= S.ArcanePower:CooldownRemainsP())) then
      if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneofPower) then return "ROP Conserve"; end
    end
    -- arcane_missiles,if=mana.pct<=95&buff.clearcasting.react,chain=1
    if S.ArcaneMissiles:IsCastableP() and (Player:ManaPercentage() <= 95 and bool(Player:BuffStackP(S.ClearcastingBuff))) then
      if HR.Cast(S.ArcaneMissiles) then return ""; end
    end
    -- arcane_barrage,if=((buff.arcane_charge.stack=buff.arcane_charge.max_stack)&((mana.pct<=variable.conserve_mana&variable.bs_rotation=0|mana.pct<=variable.conserve_mana-30&variable.bs_rotation=1)|(cooldown.arcane_power.remains>cooldown.rune_of_power.full_recharge_time&mana.pct<=variable.conserve_mana+25))|(talent.arcane_orb.enabled&cooldown.arcane_orb.remains<=gcd&cooldown.arcane_power.remains>10))|mana.pct<=(variable.conserve_mana-10)&variable.bs_rotation=0|mana.pct<=(variable.conserve_mana-50)&variable.bs_rotation=1
    if S.ArcaneBarrage:IsCastableP() and (((Player:ArcaneChargesP() == Player:ArcaneChargesMax()) and ((Player:ManaPercentage() <= VarConserveMana and VarBsRotation == 0 or Player:ManaPercentage() <= VarConserveMana - 30 and VarBsRotation == 1) or (S.ArcanePower:CooldownRemainsP() > S.RuneofPower:FullRechargeTimeP() and Player:ManaPercentage() <= VarConserveMana + 25)) or (S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemainsP() <= Player:GCD() and S.ArcanePower:CooldownRemainsP() > 10)) or Player:ManaPercentage() <= (VarConserveMana - 10) and VarBsRotation == 0 or Player:ManaPercentage() <= (VarConserveMana - 50) and VarBsRotation == 1) then
      if HR.Cast(S.ArcaneBarrage) then return ""; end
    end
    -- supernova,if=mana.pct<=95
    if S.Supernova:IsCastableP() and (Player:ManaPercentage() <= 95) then
      if HR.Cast(S.Supernova) then return ""; end
    end
    -- arcane_explosion,if=active_enemies>=3&(mana.pct>=variable.conserve_mana|buff.arcane_charge.stack=3)
    if S.ArcaneExplosion:IsCastableP() and (Cache.EnemiesCount[10] >= 3 and (Player:ManaPercentage() >= VarConserveMana or Player:ArcaneChargesP() == 3)) then
      if HR.Cast(S.ArcaneExplosion) then return ""; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsReadyP() then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsCastableP() then
      if HR.Cast(S.ArcaneBarrage) then return ""; end
    end
  end
  Movement = function()
    -- shimmer,if=movement.distance>=10
    if S.Shimmer:IsCastableP() and (movement.distance >= 10) then
      if HR.Cast(S.Shimmer) then return ""; end
    end
    -- blink,if=movement.distance>=10
    if S.Blink:IsCastableP() and (movement.distance >= 10) then
      if HR.Cast(S.Blink) then return ""; end
    end
    -- presence_of_mind
    if S.PresenceofMind:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return ""; end
    end
    -- arcane_missiles
    if S.ArcaneMissiles:IsCastableP() then
      if HR.Cast(S.ArcaneMissiles) then return ""; end
    end
    -- arcane_orb
    if S.ArcaneOrb:IsCastableP() then
      if HR.Cast(S.ArcaneOrb) then return ""; end
    end
    -- supernova
    if S.Supernova:IsCastableP() then
      if HR.Cast(S.Supernova) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell,if=target.debuff.casting.react
    -- time_warp,if=time=0&buff.bloodlust.down
    -- call_action_list,name=burn,if=burn_phase|target.time_to_die<variable.average_burn_length
    if HR.CDsON() and (bool(VarBurnPhase) or Target:TimeToDie() < VarAverageBurnLength) then
      local ShouldReturn = Burn(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=burn,if=(cooldown.arcane_power.remains=0&cooldown.evocation.remains<=variable.average_burn_length&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|(talent.charged_up.enabled&cooldown.charged_up.remains=0)))
    if HR.CDsON() and ((S.ArcanePower:CooldownRemainsP() == 0 and S.Evocation:CooldownRemainsP() <= VarAverageBurnLength and (Player:ArcaneChargesP() == Player:ArcaneChargesMax() or (S.ChargedUp:IsAvailable() and S.ChargedUp:CooldownRemainsP() == 0)))) then
      local ShouldReturn = Burn(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=burn,if=variable.bs_rotation=1&(cooldown.evocation.remains=0|cooldown.evocation.remains<=variable.average_burn_length)&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|(talent.charged_up.enabled&cooldown.charged_up.remains=0))
    if HR.CDsON() and (VarBsRotation == 1 and (S.Evocation:CooldownRemainsP() == 0 or S.Evocation:CooldownRemainsP() <= VarAverageBurnLength) and (Player:ArcaneChargesP() == Player:ArcaneChargesMax() or (S.ChargedUp:IsAvailable() and S.ChargedUp:CooldownRemainsP() == 0))) then
      local ShouldReturn = Burn(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=conserve,if=!burn_phase
    if (not bool(VarBurnPhase)) or (not HR.CDsON()) then
      local ShouldReturn = Conserve(); if ShouldReturn then return ShouldReturn; end
    end
    -- -- call_action_list,name=movement
    -- if (true) then
    --   local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    -- end
  end
end

HR.SetAPL(62, APL)
