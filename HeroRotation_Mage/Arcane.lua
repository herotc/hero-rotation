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
  ArcaneIntellect                       = Spell(1459),
  SummonArcaneFamiliar                  = Spell(205022),
  MirrorImage                           = Spell(55342),
  ArcaneBlast                           = Spell(30451),
  Evocation                             = Spell(12051),
  ChargedUp                             = Spell(205032),
  ArcaneChargeBuff                      = Spell(36032),
  PresenceofMind                        = Spell(205025),
  NetherTempest                         = Spell(114923),
  RuneofPowerBuff                       = Spell(116014),
  ArcanePowerBuff                       = Spell(12042),
  TimeWarp                              = Spell(80353),
  ArcanePower                           = Spell(12042),
  LightsJudgment                        = Spell(255647),
  RuneofPower                           = Spell(116011),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneOrb                             = Spell(153626),
  Resonance                             = Spell(205028),
  PresenceofMindBuff                    = Spell(205025),
  Overpowered                           = Spell(155147),
  ArcaneBarrage                         = Spell(44425),
  ArcaneExplosion                       = Spell(1449),
  ArcaneMissiles                        = Spell(5143),
  ClearcastingBuff                      = Spell(263725),
  RuleofThreesBuff                      = Spell(264774),
  RhoninsAssaultingArmwrapsBuff         = Spell(208081),
  Supernova                             = Spell(157980),
  ArcaneTorrent                         = Spell(50613),
  Shimmer                               = Spell(212653),
  Blink                                 = Spell(1953),
  Counterspell                          = Spell(2139)
};
local S = Spell.Mage.Arcane;

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Arcane = {
  DeadlyGrace                      = Item(127843),
  GravitySpiral                    = Item(144274),
  MysticKiltoftheRuneMaster        = Item(209280)
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
local VarTotalBurns = 0;
local VarAverageBurnLength = 0;

local EnemyRanges = {10, 40}
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

local function StartBurnPhase ()
  varBurnPhase = 1
  varBurnPhaseStart = HL.GetTime()
end

local function StopBurnPhase ()
  varBurnPhase = 0
end

--- ======= ACTION LISTS =======
local function APL()
  UpdateRanges()
  local function Precombat()
    -- flask
    -- food
    -- augmentation
    -- arcane_intellect
    if S.ArcaneIntellect:IsCastableP() and Player:BuffDownP(S.ArcaneIntellect) and (true) then
      if HR.Cast(S.ArcaneIntellect) then return ""; end
    end
    -- summon_arcane_familiar
    if S.SummonArcaneFamiliar:IsCastableP() and (true) then
      if HR.Cast(S.SummonArcaneFamiliar) then return ""; end
    end
    -- snapshot_stats
    -- mirror_image
    if S.MirrorImage:IsCastableP() and (true) then
      if HR.Cast(S.MirrorImage) then return ""; end
    end
    -- potion
    if I.DeadlyGrace:IsReady() and Settings.Commons.UsePotions and (true) then
      if HR.CastSuggested(I.DeadlyGrace) then return ""; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsCastableP() and (true) then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
  end
  local function Burn()
    -- variable,name=total_burns,op=add,value=1,if=!burn_phase
    if (not bool(VarBurnPhase)) then
      VarTotalBurns = VarTotalBurns + 1
    end
    -- start_burn_phase,if=!burn_phase
    if (not bool(VarBurnPhase)) then
      StartBurnPhase()
    end
    -- stop_burn_phase,if=burn_phase&(prev_gcd.1.evocation|(equipped.gravity_spiral&cooldown.evocation.charges=0&prev_gcd.1.evocation))&target.time_to_die>variable.average_burn_length&burn_phase_duration>0
    if (bool(VarBurnPhase) and (Player:PrevGCDP(1, S.Evocation) or (I.GravitySpiral:IsEquipped() and S.Evocation:ChargesP() == 0 and Player:PrevGCDP(1, S.Evocation))) and Target:TimeToDie() > VarAverageBurnLength and VarBurnPhaseDuration > 0) then
      StopBurnPhase()
    end
    -- mirror_image
    if S.MirrorImage:IsCastableP() and (true) then
      if HR.Cast(S.MirrorImage) then return ""; end
    end
    -- charged_up,if=buff.arcane_charge.stack<=1&(!set_bonus.tier20_2pc|cooldown.presence_of_mind.remains>5)
    if S.ChargedUp:IsCastableP() and (Player:BuffStackP(S.ArcaneChargeBuff) <= 1 and (not HL.Tier20_2Pc or S.PresenceofMind:CooldownRemainsP() > 5)) then
      if HR.Cast(S.ChargedUp) then return ""; end
    end
    -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
    if S.NetherTempest:IsCastableP() and ((Player:BuffRefreshableCP(S.NetherTempest) or not Player:BuffP(S.NetherTempest)) and Player:BuffStackP(S.ArcaneChargeBuff) == Player:ArcaneChargesMax() and Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.NetherTempest) then return ""; end
    end
    -- time_warp,if=buff.bloodlust.down&((buff.arcane_power.down&cooldown.arcane_power.remains=0)|(target.time_to_die<=buff.bloodlust.duration))
   -- if S.TimeWarp:IsCastableP() and (Player:HasNotHeroism() and ((Player:BuffDownP(S.ArcanePowerBuff) and S.ArcanePower:CooldownRemainsP() == 0) or (Target:TimeToDie() <= bloodlust:BaseDuration()))) then
  --    if HR.Cast(S.TimeWarp) then return ""; end
  --  end
    -- lights_judgment,if=buff.arcane_power.down
    if S.LightsJudgment:IsCastableP() and (Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.LightsJudgment) then return ""; end
    end
    -- rune_of_power,if=!buff.arcane_power.up&(mana.pct>=50|cooldown.arcane_power.remains=0)&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
    if S.RuneofPower:IsCastableP() and (not Player:BuffP(S.ArcanePowerBuff) and (Player:ManaPercentage() >= 50 or S.ArcanePower:CooldownRemainsP() == 0) and (Player:BuffStackP(S.ArcaneChargeBuff) == Player:ArcaneChargesMax())) then
      if HR.Cast(S.RuneofPower) then return ""; end
    end
    -- arcane_power
    if S.ArcanePower:IsCastableP() and (true) then
      if HR.Cast(S.ArcanePower) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() and (true) then
      if HR.Cast(S.BloodFury, Settings.Arcane.OffGCDasOffGCD.BloodFury) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() and (true) then
      if HR.Cast(S.Berserking, Settings.Arcane.OffGCDasOffGCD.Berserking) then return ""; end
    end
    -- presence_of_mind
    if S.PresenceofMind:IsCastableP() and (true) then
      if HR.Cast(S.PresenceofMind) then return ""; end
    end
    -- arcane_orb,if=buff.arcane_charge.stack=0|(active_enemies<3|(active_enemies<2&talent.resonance.enabled))
    if S.ArcaneOrb:IsCastableP() and (Player:BuffStackP(S.ArcaneChargeBuff) == 0 or (Cache.EnemiesCount[40] < 3 or (Cache.EnemiesCount[40] < 2 and S.Resonance:IsAvailable()))) then
      if HR.Cast(S.ArcaneOrb) then return ""; end
    end
    -- arcane_blast,if=buff.presence_of_mind.up&set_bonus.tier20_2pc&talent.overpowered.enabled&buff.arcane_power.up
    if S.ArcaneBlast:IsCastableP() and (Player:BuffP(S.PresenceofMindBuff) and HL.Tier20_2Pc and S.Overpowered:IsAvailable() and Player:BuffP(S.ArcanePowerBuff)) then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- arcane_barrage,if=(active_enemies>=3|(active_enemies>=2&talent.resonance.enabled))&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
    if S.ArcaneBarrage:IsCastableP() and ((Cache.EnemiesCount[40] >= 3 or (Cache.EnemiesCount[40] >= 2 and S.Resonance:IsAvailable())) and (Player:BuffStackP(S.ArcaneChargeBuff) == Player:ArcaneChargesMax())) then
      if HR.Cast(S.ArcaneBarrage) then return ""; end
    end
    -- arcane_explosion,if=active_enemies>=3|(active_enemies>=2&talent.resonance.enabled)
    if S.ArcaneExplosion:IsCastableP() and (Cache.EnemiesCount[10] >= 3 or (Cache.EnemiesCount[10] >= 2 and S.Resonance:IsAvailable())) then
      if HR.Cast(S.ArcaneExplosion) then return ""; end
    end
    -- arcane_missiles,if=(buff.clearcasting.react&mana.pct<=95),chain=1
    if S.ArcaneMissiles:IsCastableP() and ((bool(Player:BuffStackP(S.ClearcastingBuff)) and Player:ManaPercentage() <= 95)) then
      if HR.Cast(S.ArcaneMissiles) then return ""; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsCastableP() and (true) then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- variable,name=average_burn_length,op=set,value=(variable.average_burn_length*variable.total_burns-variable.average_burn_length+(burn_phase_duration))%variable.total_burns
    if (true) then
      VarAverageBurnLength = (VarAverageBurnLength * VarTotalBurns - VarAverageBurnLength + (VarBurnPhaseDuration)) / VarTotalBurns
    end
    -- evocation,interrupt_if=mana.pct>=97|(buff.clearcasting.react&mana.pct>=92)
    if S.Evocation:IsCastableP() and (true) then
      if HR.Cast(S.Evocation) then return ""; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsCastableP() and (true) then
      if HR.Cast(S.ArcaneBarrage) then return ""; end
    end
  end
  local function Conserve()
    -- mirror_image
    if S.MirrorImage:IsCastableP() and (true) then
      if HR.Cast(S.MirrorImage) then return ""; end
    end
    -- charged_up,if=buff.arcane_charge.stack=0
    if S.ChargedUp:IsCastableP() and (Player:BuffStackP(S.ArcaneChargeBuff) == 0) then
      if HR.Cast(S.ChargedUp) then return ""; end
    end
    -- presence_of_mind,if=set_bonus.tier20_2pc&buff.arcane_charge.stack=0
    if S.PresenceofMind:IsCastableP() and (HL.Tier20_2Pc and Player:BuffStackP(S.ArcaneChargeBuff) == 0) then
      if HR.Cast(S.PresenceofMind) then return ""; end
    end
    -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
    if S.NetherTempest:IsCastableP() and ((Player:BuffRefreshableCP(S.NetherTempest) or not Player:BuffP(S.NetherTempest)) and Player:BuffStackP(S.ArcaneChargeBuff) == Player:ArcaneChargesMax() and Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.NetherTempest) then return ""; end
    end
    -- arcane_blast,if=(buff.rule_of_threes.up|buff.rhonins_assaulting_armwraps.react)&buff.arcane_charge.stack>=3
    if S.ArcaneBlast:IsCastableP() and ((Player:BuffP(S.RuleofThreesBuff) or bool(Player:BuffStackP(S.RhoninsAssaultingArmwrapsBuff))) and Player:BuffStackP(S.ArcaneChargeBuff) >= 3) then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- rune_of_power,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&(full_recharge_time<=execute_time|recharge_time<=cooldown.arcane_power.remains|target.time_to_die<=cooldown.arcane_power.remains)
    if S.RuneofPower:IsCastableP() and (Player:BuffStackP(S.ArcaneChargeBuff) == Player:ArcaneChargesMax() and (S.RuneofPower:FullRechargeTimeP() <= S.RuneofPower:ExecuteTime() or S.RuneofPower:RechargeP() <= S.ArcanePower:CooldownRemainsP() or Target:TimeToDie() <= S.ArcanePower:CooldownRemainsP())) then
      if HR.Cast(S.RuneofPower) then return ""; end
    end
    -- arcane_missiles,if=mana.pct<=95&buff.clearcasting.react,chain=1
    if S.ArcaneMissiles:IsCastableP() and (Player:ManaPercentage() <= 95 and bool(Player:BuffStackP(S.ClearcastingBuff))) then
      if HR.Cast(S.ArcaneMissiles) then return ""; end
    end
    -- arcane_blast,if=equipped.mystic_kilt_of_the_rune_master&buff.arcane_charge.stack=0
    if S.ArcaneBlast:IsCastableP() and (I.MysticKiltoftheRuneMaster:IsEquipped() and Player:BuffStackP(S.ArcaneChargeBuff) == 0) then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- arcane_barrage,if=(buff.arcane_charge.stack=buff.arcane_charge.max_stack)&(mana.pct<=35|(talent.arcane_orb.enabled&cooldown.arcane_orb.remains<=gcd))
    if S.ArcaneBarrage:IsCastableP() and ((Player:BuffStackP(S.ArcaneChargeBuff) == Player:ArcaneChargesMax()) and (Player:ManaPercentage() <= 35 or (S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemainsP() <= Player:GCD()))) then
      if HR.Cast(S.ArcaneBarrage) then return ""; end
    end
    -- supernova,if=mana.pct<=95
    if S.Supernova:IsCastableP() and (Player:ManaPercentage() <= 95) then
      if HR.Cast(S.Supernova) then return ""; end
    end
    -- arcane_explosion,if=active_enemies>=3&(mana.pct>=40|buff.arcane_charge.stack=3)
    if S.ArcaneExplosion:IsCastableP() and (Cache.EnemiesCount[10] >= 3 and (Player:ManaPercentage() >= 40 or Player:BuffStackP(S.ArcaneChargeBuff) == 3)) then
      if HR.Cast(S.ArcaneExplosion) then return ""; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() and (true) then
      if HR.Cast(S.ArcaneTorrent, Settings.Arcane.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsCastableP() and (true) then
      if HR.Cast(S.ArcaneBlast) then return ""; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsCastableP() and (true) then
      if HR.Cast(S.ArcaneBarrage) then return ""; end
    end
  end
  local function Movement()
    -- shimmer,if=movement.distance>=10
    if S.Shimmer:IsCastableP() and (movement.distance >= 10) then
      if HR.Cast(S.Shimmer) then return ""; end
    end
    -- blink,if=movement.distance>=10
    if S.Blink:IsCastableP() and (movement.distance >= 10) then
      if HR.Cast(S.Blink) then return ""; end
    end
    -- presence_of_mind
    if S.PresenceofMind:IsCastableP() and (true) then
      if HR.Cast(S.PresenceofMind) then return ""; end
    end
    -- arcane_missiles
    if S.ArcaneMissiles:IsCastableP() and (true) then
      if HR.Cast(S.ArcaneMissiles) then return ""; end
    end
    -- arcane_orb
    if S.ArcaneOrb:IsCastableP() and (true) then
      if HR.Cast(S.ArcaneOrb) then return ""; end
    end
    -- supernova
    if S.Supernova:IsCastableP() and (true) then
      if HR.Cast(S.Supernova) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  -- counterspell,if=target.debuff.casting.react
  if S.Counterspell:IsCastableP() and (Target:IsCasting()) then
    if HR.Cast(S.Counterspell) then return ""; end
  end
  -- time_warp,if=time=0&buff.bloodlust.down
 -- if S.TimeWarp:IsCastableP() and (HL.CombatTime() == 0 and Player:HasNotHeroism()) then
 --   if HR.Cast(S.TimeWarp) then return ""; end
--  end
  -- call_action_list,name=burn,if=burn_phase|target.time_to_die<variable.average_burn_length|(cooldown.arcane_power.remains=0&cooldown.evocation.remains<=variable.average_burn_length&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|(talent.charged_up.enabled&cooldown.charged_up.remains=0)))
  if (bool(VarBurnPhase) or Target:TimeToDie() < VarAverageBurnLength or (S.ArcanePower:CooldownRemainsP() == 0 and S.Evocation:CooldownRemainsP() <= VarAverageBurnLength and (Player:BuffStackP(S.ArcaneChargeBuff) == Player:ArcaneChargesMax() or (S.ChargedUp:IsAvailable() and S.ChargedUp:CooldownRemainsP() == 0)))) then
    local ShouldReturn = Burn(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=conserve,if=!burn_phase
  if (not bool(VarBurnPhase)) then
    local ShouldReturn = Conserve(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=movement
  if (true) then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

HR.SetAPL(62, APL)
