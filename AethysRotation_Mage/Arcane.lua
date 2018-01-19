--- ============================ HEADER ============================
--- ======= LOCALIZE =======
--- Localize Vars
-- Addon
local addonName, addonTable = ...;
-- AethysCore
local AC      = AethysCore;
local Cache   = AethysCache;
local Unit    = AC.Unit;
local Player  = Unit.Player;
local Target  = Unit.Target;
local Spell   = AC.Spell;
local Item    = AC.Item;
-- AethysRotation
local AR = AethysRotation;
-- Lua

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
local Everyone = AR.Commons.Everyone;
local Mage = AR.Commons.Mage;
-- Spells
if not Spell.Mage then Spell.Mage = {}; end

Spell.Mage.Arcane = {
  -- Racials
  ArcaneTorrent         = Spell(25046),
  Berserking            = Spell(26297),
  BloodFury             = Spell(20572),
  GiftoftheNaaru        = Spell(59547),
  Shadowmeld            = Spell(58984),

  -- Abilities
  ArcaneCharges		      = Spell(36032),
  ArcaneBlast           = Spell(30451),
  ArcaneBarrage         = Spell(44425),
  ArcaneExplosion       = Spell(1449),
  ArcaneMissiles        = Spell(5143),
  ArcaneMissilesProc    = Spell(79683),
  ArcanePower           = Spell(12042),
  Evocation             = Spell(12051),
  PresenceofMind        = Spell(205025),
  ExpandingMind	        = Spell(253262),
  Counterspell          = Spell(2139),
  SpellSteal            = Spell(30449),
  Polymorph             = Spell(118),
  TimeWarp              = Spell(80353),

  -- Talents
  ArcaneFamiliar        = Spell(205022),
  Amplification         = Spell(236628),
  WordsOfPower          = Spell(205035),

  MirrorImage           = Spell(55342),
  RuneofPower           = Spell(116011),
  IncantersFlow         = Spell(1463),

  Supernova             = Spell(157980),
  ChargedUp             = Spell(205032),
  Resonance             = Spell(205028),

  NetherTempest         = Spell(114923),
  UnstableMagic         = Spell(157976),
  Erosion               = Spell(205039),

  Overpowered           = Spell(155147),
  TemporalFlux          = Spell(234302),
  ArcaneOrb             = Spell(153626),

  -- Artifact
  MarkofAluneth         = Spell(224968),

  -- Defensive
  PrismaticBarrier      = Spell(235450),
  IceBlock              = Spell(45438),
  GreaterInvisibility   = Spell(110959),

  -- Legendaries
  RhoninsAssaultingArmwrapsProc = Spell(208081),  -- Arcane Mage Bracer Buff

  -- Misc
  PotionOfProlongedPowerBuff  = Spell(229206),
  PotionOfDeadlyGraceBuff     = Spell(188027),
  ErosionDebuff               = Spell(210134),
  RuneofPowerBuff             = Spell(116014)
};

local S = Spell.Mage.Arcane;
-- Items
if not Item.Mage then Item.Mage = {}; end
Item.Mage.Arcane = {
  PotionOfDeadlyGrace         = Item(127843),
  MysticKiltofTheRuneMaster   = Item(209280, {7}),
  MantleOfTheFirstKirinTor    = Item(248098, {3}),
  KiljaedensBurningWish       = Item(144259, {13, 14}),
  TarnishedSentinel			  = Item(147017, {13, 14})
}
local I = Item.Mage.Arcane;
-- Rotation Var
local ShouldReturn; -- Used to get the return string
local ArcaneMissilesProcMax = 3;
local PresenceOfMindMax = 2;
local range = 40
local var_init = false
local var_calcCombat = false
local EnemyRanges = {10, 40}
local v_timeUntilBurn, v_averageBurnLength, v_totalBurn, v_burnPhase, v_burnPhaseDuration, v_burnPhaseStart

-- GUI Settings
local Settings = {
General = AR.GUISettings.General,
Commons = AR.GUISettings.APL.Mage.Commons,
Arcane = AR.GUISettings.APL.Mage.Arcane
};

-------- ACTIONS --------

local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    AC.GetEnemies(i);
  end
end
  
local function Var_TimeUntilBurn ()
  -- variable,name=time_until_burn,op=set,value=cooldown.arcane_power.remains
  v_timeUntilBurn = S.ArcanePower:CooldownRemainsP()
  -- variable,name=time_until_burn,op=max,value=cooldown.evocation.remains-variable.average_burn_length
  v_timeUntilBurn = math.max(v_timeUntilBurn, S.Evocation:CooldownRemainsP() - v_averageBurnLength)
  -- variable,name=time_until_burn,op=max,value=cooldown.presence_of_mind.remains,if=set_bonus.tier20_2pc
  if AC.Tier20_2Pc then
    v_timeUntilBurn = math.max(v_timeUntilBurn, S.PresenceofMind:CooldownRemainsP())
  end
  -- variable,name=time_until_burn,op=max,value=action.rune_of_power.usable_in,if=talent.rune_of_power.enabled
  if (S.RuneofPower:IsAvailable()) then
    v_timeUntilBurn = math.max(v_timeUntilBurn, S.RuneofPower:UsableInP())
  end
  -- variable,name=time_until_burn,op=max,value=cooldown.charged_up.remains,if=talent.charged_up.enabled&set_bonus.tier21_2pc
  if (S.ChargedUp:IsAvailable() and AC.Tier21_2Pc) then
    v_timeUntilBurn = math.max(v_timeUntilBurn, S.ChargedUp:CooldownRemainsP())
  end
  -- variable,name=time_until_burn,op=reset,if=target.time_to_die<variable.average_burn_length
  if (Target:TimeToDie() < v_averageBurnLength) then
    v_timeUntilBurn = 0
  end
end

local function Var_BurnPhaseDuration ()
  if v_burnPhase then
    v_burnPhaseDuration = AC.GetTime() - v_burnPhaseStart
  --else
  --  v_burnPhaseDuration = 0
  end
end

local function Var_AverageBurnLength ()
  -- variable,name=average_burn_length,op=set,value=(variable.average_burn_length*variable.total_burns-variable.average_burn_length+burn_phase_duration)%variable.total_burns
  v_averageBurnLength = (v_averageBurnLength * v_totalBurn - v_averageBurnLength + v_burnPhaseDuration) / v_totalBurn
end

local function VarCalc ()
  Var_TimeUntilBurn()
  Var_BurnPhaseDuration()
  if v_totalBurn > 0 then
    Var_AverageBurnLength()
  end
end

local function VarInit ()
  if not var_init or (AC.CombatTime() > 0 and not var_calcCombat) then
    v_totalBurn = 0
    v_burnPhase = false
    v_burnPhaseDuration = 0
    v_averageBurnLength = 0

    var_init=true
    var_calcCombat=true
  end
end

local function RoPDuration ()
  if AC.RoPTime == 0 then return 0 end
  return AC.OffsetRemains(AC.GetTime() - AC.RoPTime, "Auto")
end

local function FuturArcaneCharges ()
  local ArcaneCharges = Player:ArcaneCharges()
  if not Player:IsCasting() then
    return ArcaneCharges
  else
    if Player:IsCasting(S.ArcaneBlast) then
      ArcaneCharges = ArcaneCharges + 1
    elseif Player:IsCasting(S.ArcaneMissiles) then
      ArcaneCharges = ArcaneCharges + 1
    else
      ArcaneCharges = ArcaneCharges
    end
  end
  if ArcaneCharges > Player:ArcaneChargesMax() then
    ArcaneCharges = Player:ArcaneChargesMax()
  end
  return ArcaneCharges
end

local function Build ()
  -- arcane_orb
  if S.ArcaneOrb:IsCastableP() and Player:ManaP() >= S.ArcaneOrb:Cost() then
    if AR.Cast(S.ArcaneOrb) then return ""; end
  end
  -- arcane_missiles,if=active_enemies<3&(variable.arcane_missiles_procs=ArcaneMissilesProcMax|(variable.arcane_missiles_procs&mana.pct<=50&buff.arcane_charge.stack=3))
  if S.ArcaneMissiles:IsCastableP() and (Cache.EnemiesCount[range] < 3 and (Player:BuffStackP(S.ArcaneMissilesProc) == ArcaneMissilesProcMax or (Player:BuffStackP(S.ArcaneMissilesProc) > 0 and Player:ManaPercentage () <= 50 and Player:ArcaneCharges() == 3))) then
    if AR.Cast(S.ArcaneMissiles) then return ""; end
  end
  -- arcane_explosion,if=active_enemies>1
  if S.ArcaneExplosion:IsCastableP() and Cache.EnemiesCount[10] > 1 and Player:ManaP() >= S.ArcaneExplosion:Cost() then
    if AR.Cast(S.ArcaneExplosion) then return ""; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsCastableP() and Player:ManaP() >= S.ArcaneBlast:Cost() then
    if AR.Cast(S.ArcaneBlast) then return ""; end
  end
end

local function Burn ()
  -- variable,name=total_burns,op=add,value=1,if=!burn_phase
  if not v_burnPhase then
    v_totalBurn = v_totalBurn + 1
    v_burnPhaseDuration = 0
  end
  -- start_burn_phase,if=!burn_phase
  if not v_burnPhase then
    v_burnPhase = true
    v_burnPhaseStart = AC.GetTime()
  end
  -- stop_burn_phase,if=prev_gcd.1.evocation&cooldown.evocation.charges=0&burn_phase_duration>0
  if Player:PrevGCDP(1, S.Evocation) and S.Evocation:ChargesP() == 0 and v_burnPhaseDuration > 0 then
  -- AR.Print("Stop burn")
    v_burnPhase = false
  end
  -- nether_tempest,if=refreshable|!ticking
  if S.NetherTempest:IsCastableP() and S.NetherTempest:IsAvailable() and Player:ManaP() >= S.NetherTempest:Cost() and (Target:DebuffRefreshableCP(S.NetherTempest) or not (Target:DebuffRemainsP(S.NetherTempest) > 0)) then
    if AR.Cast(S.NetherTempest) then return ""; end
  end
  -- mark_of_aluneth
  if S.MarkofAluneth:IsCastableP() then
    if AR.Cast(S.MarkofAluneth) then return ""; end
  end
  -- mirror_image
  if AR.CDsON() and S.MirrorImage:IsCastableP() and Player:ManaP() >= S.MirrorImage:Cost() then
    if AR.Cast(S.MirrorImage) then return ""; end
  end
  -- rune_of_power,if=mana.pct>30|(buff.arcane_power.up|cooldown.arcane_power.up)
  if AR.CDsON() and S.RuneofPower:IsCastableP() and (Player:ManaPercentage() > 30 or (Player:BuffRemainsP(S.ArcanePower) > 0 or S.ArcanePower:CooldownUpP())) and not Player:IsCasting(S.RuneofPower) then
    if AR.Cast(S.RuneofPower) then return ""; end
  end
  -- arcane_power
  if AR.CDsON() and S.ArcanePower:IsCastableP() then
    if AR.Cast(S.ArcanePower) then return ""; end
  end
  -- blood_fury
  if AR.CDsON() and S.BloodFury:IsCastableP() then
    if AR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- berserking
  if AR.CDsON() and S.Berserking:IsCastableP() then
    if AR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- arcane_torrent
  if AR.CDsON() and S.ArcaneTorrent:IsCastableP() then
    if AR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- potion,if=buff.arcane_power.up&(buff.berserking.up|buff.blood_fury.up|!(race.troll|race.orc))
  -- if I.PotionOfDeadlyGrace:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.ArcanePower) and (Player:BuffP(S.BerserkingBuff) or Player:BuffP(S.BloodFuryBuff) or not (Player:Race()=="Troll" or Player:Race()=="Orc"))) then
  -- if AR.CastSuggested(I.PotionOfDeadlyGrace) then return ""; end
  -- end
  -- use_items,if=buff.arcane_power.up|target.time_to_die<cooldown.arcane_power.remains
  if I.TarnishedSentinel:IsEquipped() and I.TarnishedSentinel:IsReady() and (Player:BuffP(S.ArcanePower) or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP()) then
    if AR.Cast(I.TarnishedSentinel) then return ""; end
  end
  if I.KiljaedensBurningWish:IsEquipped() and I.KiljaedensBurningWish:IsReady() and (Player:BuffP(S.ArcanePower) or Target:TimeToDie() < S.ArcanePower:CooldownRemainsP()) then
    if AR.Cast(I.KiljaedensBurningWish) then return ""; end
  end
  -- arcane_barrage,if=set_bonus.tier21_2pc&((set_bonus.tier20_2pc&cooldown.presence_of_mind.up)|(talent.charged_up.enabled&cooldown.charged_up.up))&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.expanding_mind.down
  if S.ArcaneBarrage:IsCastableP() and Player:ManaP() >= S.ArcaneBarrage:Cost() and (AC.Tier21_2Pc and ((AC.Tier20_2Pc and S.PresenceofMind:CooldownUpP()) or (S.ChargedUp:IsAvailable() and S.ChargedUp:CooldownUpP())) and FuturArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDownP(S.ExpandingMindBuff)) then
    if AR.Cast(S.ArcaneBarrage) then return ""; end
  end
  -- presence_of_mind,if=((mana.pct>30|buff.arcane_power.up)&set_bonus.tier20_2pc)|buff.rune_of_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time|buff.arcane_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
  if AR.CDsON() and S.PresenceofMind:IsCastableP() and not Player:Buff(S.PresenceofMind) and (((Player:ManaPercentage() > 30 or Player:BuffRemainsP(S.ArcanePower) > 0) and AC.Tier20_2Pc) or RoPDuration () <= PresenceOfMindMax * S.ArcaneBlast:ExecuteTime() or Player:BuffRemainsP(S.ArcanePower) <= PresenceOfMindMax * S.ArcaneBlast:ExecuteTime()) then
    if AR.Cast(S.PresenceofMind) then return ""; end
  end
  -- charged_up,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ChargedUp:IsCastableP() and (FuturArcaneCharges() < Player:ArcaneChargesMax()) then
    if AR.Cast(S.ChargedUp) then return ""; end
  end
  -- arcane_orb
  if S.ArcaneOrb:IsCastableP() and Player:ManaP() >= S.ArcaneOrb:Cost() then
    if AR.Cast(S.ArcaneOrb) then return ""; end
  end
  -- arcane_barrage,if=active_enemies>4&equipped.mantle_of_the_first_kirin_tor&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastableP() and Player:ManaP() >= S.ArcaneBarrage:Cost() and (Cache.EnemiesCount[range] > 4 and I.MantleOfTheFirstKirinTor:IsEquipped() and FuturArcaneCharges() == Player:ArcaneChargesMax()) then
    if AR.Cast(S.ArcaneBarrage) then return ""; end
  end
  -- arcane_missiles,if=variable.arcane_missiles_procs=buff.arcane_missiles.max_stack&active_enemies<3
  if S.ArcaneMissiles:IsCastableP() and Player:ManaP() >= S.ArcaneMissiles:Cost() and (Player:BuffStackP(S.ArcaneMissilesProc) == ArcaneMissilesProcMax and Cache.EnemiesCount[range] < 3) then
    if AR.Cast(S.ArcaneMissiles) then return ""; end
  end
  -- arcane_blast,if=buff.presence_of_mind.up
  if S.ArcaneBlast:IsCastableP() and Player:ManaP() >= S.ArcaneBlast:Cost() and Player:Buff(S.PresenceofMind) then
    if AR.Cast(S.ArcaneBlast) then return ""; end
  end
  -- arcane_explosion,if=active_enemies>1
  if S.ArcaneExplosion:IsCastableP() and Player:ManaP() >= S.ArcaneExplosion:Cost() and Cache.EnemiesCount[10] > 1 then
    if AR.Cast(S.ArcaneExplosion) then return ""; end
  end
  -- arcane_missiles,if=variable.arcane_missiles_procs
  if S.ArcaneMissiles:IsCastableP() and Player:ManaP() >= S.ArcaneMissiles:Cost() and Player:BuffStackP(S.ArcaneMissilesProc) > 0 then
    if AR.Cast(S.ArcaneMissiles) then return ""; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsCastableP() and Player:ManaP() >= S.ArcaneBlast:Cost() then
    if AR.Cast(S.ArcaneBlast) then return ""; end
  end
  -- evocation,interrupt_if=ticks=2|mana.pct>=85,interrupt_immediate=1
  if S.Evocation:IsCastableP() then
    if AR.Cast(S.Evocation) then return ""; end
  end
end

local function Conserve ()
  -- AR.Print("In Conserve phase")
  -- mirror_image,if=variable.time_until_burn>recharge_time|variable.time_until_burn>target.time_to_die
  if AR.CDsON() and S.MirrorImage:IsCastableP() and Player:ManaP() >= S.MirrorImage:Cost() and (v_timeUntilBurn > S.MirrorImage:RechargeP() or v_timeUntilBurn > Target:TimeToDie()) then
    if AR.Cast(S.MirrorImage) then return ""; end
  end
  -- mark_of_aluneth,if=mana.pct<85
  if S.MarkofAluneth:IsCastableP() and (Player:ManaPercentage() < 85) then
    if AR.Cast(S.MarkofAluneth) then return ""; end
  end
  -- strict_sequence,name=miniburn,if=talent.rune_of_power.enabled&set_bonus.tier20_4pc&variable.time_until_burn>30:rune_of_power:arcane_barrage:presence_of_mind
  if (S.RuneofPower:IsAvailable() and AC.Tier20_4Pc and v_timeUntilBurn > 30) then
    if AR.CastQueue(S.RuneofPower, S.ArcaneBarrage, S.PresenceofMind) then return; end
  end
  -- rune_of_power,if=full_recharge_time<=execute_time|prev_gcd.1.mark_of_aluneth
  if AR.CDsON() and S.RuneofPower:IsCastableP() and (S.RuneofPower:FullRechargeTimeP() <= S.RuneofPower:ExecuteTime() or Player:PrevGCDP(1, S.MarkofAluneth)) and not Player:IsCasting(S.RuneofPower) then
    if AR.Cast(S.RuneofPower) then return ""; end
  end
  -- strict_sequence,name=abarr_cu_combo,if=talent.charged_up.enabled&cooldown.charged_up.recharge_time<variable.time_until_burn:arcane_barrage:charged_up
  if (S.ChargedUp:IsAvailable() and S.ChargedUp:RechargeP() < v_timeUntilBurn) then
    if AR.CastQueue(S.ArcaneBarrage, S.ChargedUp) then return ""; end
  end
  -- arcane_missiles,if=variable.arcane_missiles_procs=buff.arcane_missiles.max_stack&active_enemies<3
  if S.ArcaneMissiles:IsCastableP() and Player:ManaP() >= S.ArcaneMissiles:Cost() and (Player:BuffStackP(S.ArcaneMissilesProc) == ArcaneMissilesProcMax and Cache.EnemiesCount[range] < 3) then
    if AR.Cast(S.ArcaneMissiles) then return ""; end
  end
  -- supernova
  if S.Supernova:IsCastableP() then
    if AR.Cast(S.Supernova) then return ""; end
  end
  -- nether_tempest,if=refreshable|!ticking
  if S.NetherTempest:IsCastableP() and S.NetherTempest:IsAvailable() and Player:ManaP() >= S.NetherTempest:Cost() and (Target:DebuffRefreshableCP(S.NetherTempest) or not (Target:DebuffRemainsP(S.NetherTempest) > 0)) then
    if AR.Cast(S.NetherTempest) then return ""; end
  end
  -- arcane_explosion,if=active_enemies>1&(mana.pct>=70-(10*equipped.mystic_kilt_of_the_rune_master))
  if S.ArcaneExplosion:IsCastableP() and Player:ManaP() >= S.ArcaneExplosion:Cost() and (Cache.EnemiesCount[10] > 1 and (Player:ManaPercentage() >= 70)) then
    if AR.Cast(S.ArcaneExplosion) then return ""; end
  end
  if S.ArcaneExplosion:IsCastableP() and Player:ManaP() >= S.ArcaneExplosion:Cost() and (Cache.EnemiesCount[10] > 1 and (Player:ManaPercentage() >= 60 and I.MysticKiltofTheRuneMaster:IsEquipped())) then
    if AR.Cast(S.ArcaneExplosion) then return ""; end
  end
  -- arcane_blast,if=mana.pct>=90|buff.rhonins_assaulting_armwraps.up|(buff.rune_of_power.remains>=cast_time&equipped.mystic_kilt_of_the_rune_master)
  if S.ArcaneBlast:IsCastableP() and Player:ManaP() >= S.ArcaneBlast:Cost() and Player:ManaPercentage() >= 90 or Player:BuffRemainsP(S.RhoninsAssaultingArmwrapsProc) > 0 or (RoPDuration() >= S.ArcaneBlast:CastTime() and I.MysticKiltofTheRuneMaster:IsEquipped()) then
    if AR.Cast(S.ArcaneBlast) then return ""; end
  end
  -- arcane_missiles,if=variable.arcane_missiles_procs
  if S.ArcaneMissiles:IsCastableP() and Player:ManaP() >= S.ArcaneMissiles:Cost() and Player:BuffStackP(S.ArcaneMissilesProc) > 0 then
    if AR.Cast(S.ArcaneMissiles) then return ""; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastableP() and Player:ManaP() >= S.ArcaneBarrage:Cost() then
    if AR.Cast(S.ArcaneBarrage) then return ""; end
  end
  -- arcane_explosion,if=active_enemies>1
  if S.ArcaneExplosion:IsCastableP() and Player:ManaP() >= S.ArcaneExplosion:Cost() and Cache.EnemiesCount[10] > 1 then
    if AR.Cast(S.ArcaneExplosion) then return ""; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsCastableP() and Player:ManaP() >= S.ArcaneBlast:Cost() then
    if AR.Cast(S.ArcaneBlast) then return ""; end
  end
end

local function APL ()
  --todo :
  -- strict sequence
  -- evocation
  -- counterspell
  -- cancelBuff

  -- Unit Update
  
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate();
  VarInit()
  VarCalc()

  -- Defensives

  -- Out of Combat
  if not Player:AffectingCombat() then
    if var_calcCombat then var_calcCombat = false end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener

    --precast
    -- arcane_blast
    if Everyone.TargetIsValid() and Target:IsInRange(range) then
      if AR.Cast(S.ArcaneBlast) then return ""; end
    end
    return
  end

  -- In Combat
  if Everyone.TargetIsValid() then    
    -- counterspell,if=target.debuff.casting.react
    -- if S.Counterspell:IsCastable(S.Counterspell) and (target.debuff.casting.react) then
    -- if AR.Cast(S.Counterspell) then return ""; end
    -- end

    -- time_warp,if=buff.bloodlust.down&(time=0|(buff.arcane_power.up&(buff.potion.up|!action.potion.usable))|target.time_to_die<=buff.bloodlust.duration)
    if AR.CDsON() and Settings.Commons.UseTimeWarp and S.TimeWarp:IsCastable() and (not Player:HasHeroism() and (AC.CombatTime() < 3 or (Player:BuffRemainsP(S.ArcanePower) > 0 and (Player:BuffRemainsP(S.PotionOfDeadlyGrace) > 0 or not I.PotionOfDeadlyGrace:IsReady())) or Target:TimeToDie() <= S.TimeWarp:BaseDuration())) then
      if AR.Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return ""; end
    end

    -- cancel_buff,name=presence_of_mind,if=active_enemies>1&set_bonus.tier20_2pc
    -- if S.CancelBuff:IsCastable(S.CancelBuff) and (active_enemies > 1 and set_bonus.tier20_2pc) then
    -- if AR.Cast(S.CancelBuff) then return ""; end
    -- end

    -- call_action_list,name=build,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack&!burn_phase
    if (FuturArcaneCharges() < Player:ArcaneChargesMax() and not v_burnPhase) then
      local ShouldReturn = Build(); if ShouldReturn then return ShouldReturn; end
    end

    -- call_action_list,name=burn,if=(buff.arcane_charge.stack=buff.arcane_charge.max_stack&variable.time_until_burn=0)|burn_phase
    if ((FuturArcaneCharges() == Player:ArcaneChargesMax() and v_timeUntilBurn == 0) or v_burnPhase) then
      local ShouldReturn = Burn(); if ShouldReturn then return ShouldReturn; end
    end

    -- call_action_list,name=conserve
    local ShouldReturn = Conserve(); 
    if ShouldReturn then return ShouldReturn; end
  
  end
end

AR.SetAPL(62, APL);

--- ======= SIMC =======
--- Last Update: 01/02/2018

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- actions.precombat+=/summon_arcane_familiar
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/mirror_image
-- actions.precombat+=/potion
-- actions.precombat+=/arcane_blast

-- # Executed every time the actor is available.
-- # Interrupt the boss when possible.
-- actions=counterspell,if=target.debuff.casting.react
-- # 3 different lust usages to support Shard: on pull; during Arcane Power (with potion, preferably); end of fight.
-- actions+=/time_warp,if=buff.bloodlust.down&(time=0|(buff.arcane_power.up&(buff.potion.up|!action.potion.usable))|target.time_to_die<=buff.bloodlust.duration)
-- # Set variables used throughout the APL.
-- actions+=/call_action_list,name=variables
-- # AoE scenarios will delay our Presence of Mind cooldown because we'll be using Arcane Explosion instead of Arcane Blast, so we cancel the aura immediately.
-- actions+=/cancel_buff,name=presence_of_mind,if=active_enemies>1&set_bonus.tier20_2pc
-- # Build Arcane Charges before doing anything else. Burn phase has some specific actions for building Arcane Charges, so we avoid entering this list if currently burning.
-- actions+=/call_action_list,name=build,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack&!burn_phase
-- # Enter burn actions if we're ready to burn, or already burning.
-- actions+=/call_action_list,name=burn,if=(buff.arcane_charge.stack=buff.arcane_charge.max_stack&variable.time_until_burn=0)|burn_phase
-- # Fallback to conserve rotation.
-- actions+=/call_action_list,name=conserve

-- actions.build=arcane_orb
-- # Use Arcane Missiles at max stacks to avoid munching a proc. Alternatively, we can cast at 3 stacks of Arcane Charge to conserve mana.
-- actions.build+=/arcane_missiles,if=active_enemies<3&(variable.arcane_missiles_procs=buff.arcane_missiles.max_stack|(variable.arcane_missiles_procs&mana.pct<=50&buff.arcane_charge.stack=3)),chain=1
-- actions.build+=/arcane_explosion,if=active_enemies>1
-- actions.build+=/arcane_blast

-- # Increment our burn phase counter. Whenever we enter the `burn` actions without being in a burn phase, it means that we are about to start one.
-- actions.burn=variable,name=total_burns,op=add,value=1,if=!burn_phase
-- # The burn_phase variable is a flag indicating whether or not we are in a burn phase. It is set to 1 (True) with start_burn_phase, and 0 (False) with stop_burn_phase.
-- actions.burn+=/start_burn_phase,if=!burn_phase
-- # Evocation is the end of our burn phase, but we check available charges in case of Gravity Spiral. The final burn_phase_duration check is to prevent an infinite loop in SimC.
-- actions.burn+=/stop_burn_phase,if=prev_gcd.1.evocation&cooldown.evocation.charges=0&burn_phase_duration>0
-- # Use during pandemic refresh window or if the dot is missing.
-- actions.burn+=/nether_tempest,if=refreshable|!ticking
-- actions.burn+=/mark_of_aluneth
-- actions.burn+=/mirror_image
-- # Prevents using RoP at super low mana.
-- actions.burn+=/rune_of_power,if=mana.pct>30|(buff.arcane_power.up|cooldown.arcane_power.up)
-- actions.burn+=/arcane_power
-- actions.burn+=/blood_fury
-- actions.burn+=/berserking
-- actions.burn+=/arcane_torrent
-- # For Troll/Orc, it's best to sync potion with their racial buffs.
-- actions.burn+=/potion,if=buff.arcane_power.up&(buff.berserking.up|buff.blood_fury.up|!(race.troll|race.orc))
-- # Pops any on-use items, e.g., Tarnished Sentinel Medallion.
-- actions.burn+=/use_items,if=buff.arcane_power.up|target.time_to_die<cooldown.arcane_power.remains
-- # With 2pt20 or Charged Up we are able to extend the damage buff from 2pt21.
-- actions.burn+=/arcane_barrage,if=set_bonus.tier21_2pc&((set_bonus.tier20_2pc&cooldown.presence_of_mind.up)|(talent.charged_up.enabled&cooldown.charged_up.up))&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.expanding_mind.down
-- # With T20, use PoM at start of RoP/AP for damage buff. Without T20, use PoM at end of RoP/AP to cram in two final Arcane Blasts. Includes a mana condition to prevent using PoM at super low mana.
-- actions.burn+=/presence_of_mind,if=((mana.pct>30|buff.arcane_power.up)&set_bonus.tier20_2pc)|buff.rune_of_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time|buff.arcane_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
-- # Use Charged Up to regain Arcane Charges after dumping to refresh 2pt21 buff.
-- actions.burn+=/charged_up,if=buff.arcane_charge.stack<buff.arcane_charge.max_stack
-- actions.burn+=/arcane_orb
-- # Arcane Barrage has a good chance of launching an Arcane Orb at max Arcane Charge stacks.
-- actions.burn+=/arcane_barrage,if=active_enemies>4&equipped.mantle_of_the_first_kirin_tor&buff.arcane_charge.stack=buff.arcane_charge.max_stack
-- # Arcane Missiles are good, but not when there's multiple targets up.
-- actions.burn+=/arcane_missiles,if=variable.arcane_missiles_procs=buff.arcane_missiles.max_stack&active_enemies<3,chain=1
-- # Get PoM back on cooldown as soon as possible.
-- actions.burn+=/arcane_blast,if=buff.presence_of_mind.up
-- actions.burn+=/arcane_explosion,if=active_enemies>1
-- actions.burn+=/arcane_missiles,if=variable.arcane_missiles_procs>1,chain=1
-- actions.burn+=/arcane_blast
-- # Now that we're done burning, we can update the average_burn_length with the length of this burn.
-- actions.burn+=/variable,name=average_burn_length,op=set,value=(variable.average_burn_length*variable.total_burns-variable.average_burn_length+burn_phase_duration)%variable.total_burns
-- # That last tick of Evocation is a waste; it's better for us to get back to casting.
-- actions.burn+=/evocation,interrupt_if=ticks=2|mana.pct>=85,interrupt_immediate=1

-- actions.conserve=mirror_image,if=variable.time_until_burn>recharge_time|variable.time_until_burn>target.time_to_die
-- actions.conserve+=/mark_of_aluneth,if=mana.pct<85
-- actions.conserve+=/strict_sequence,name=miniburn,if=talent.rune_of_power.enabled&set_bonus.tier20_4pc&variable.time_until_burn>30:rune_of_power:arcane_barrage:presence_of_mind
-- # Use if we're about to cap on stacks, or we just used MoA.
-- actions.conserve+=/rune_of_power,if=full_recharge_time<=execute_time|prev_gcd.1.mark_of_aluneth
-- # We want Charged Up for our burn phase to refresh 2pt21 buff, but if we have time to let it recharge we can use it during conserve.
-- actions.conserve+=/strict_sequence,name=abarr_cu_combo,if=talent.charged_up.enabled&cooldown.charged_up.recharge_time<variable.time_until_burn:arcane_barrage:charged_up
-- # Arcane Missiles are good, but not when there's multiple targets up.
-- actions.conserve+=/arcane_missiles,if=variable.arcane_missiles_procs=buff.arcane_missiles.max_stack&active_enemies<3,chain=1
-- actions.conserve+=/supernova
-- # Use during pandemic refresh window or if the dot is missing.
-- actions.conserve+=/nether_tempest,if=refreshable|!ticking
-- # AoE until about 70% mana. We can go a little further with kilt, down to 60% mana.
-- actions.conserve+=/arcane_explosion,if=active_enemies>1&(mana.pct>=70-(10*equipped.mystic_kilt_of_the_rune_master))
-- # Use Arcane Blast if we have the mana for it or a proc from legendary wrists. With the Kilt we can cast freely.
-- actions.conserve+=/arcane_blast,if=mana.pct>=90|buff.rhonins_assaulting_armwraps.up|(buff.rune_of_power.remains>=cast_time&equipped.mystic_kilt_of_the_rune_master)
-- actions.conserve+=/arcane_missiles,if=variable.arcane_missiles_procs,chain=1
-- actions.conserve+=/arcane_barrage
-- # The following two lines are here in case Arcane Barrage is on cooldown.
-- actions.conserve+=/arcane_explosion,if=active_enemies>1
-- actions.conserve+=/arcane_blast

-- # Track the number of Arcane Missiles procs that we have.
-- actions.variables=variable,name=arcane_missiles_procs,op=set,value=buff.arcane_missiles.react
-- # Burn condition #1: Arcane Power has to be available.
-- actions.variables+=/variable,name=time_until_burn,op=set,value=cooldown.arcane_power.remains
-- # Burn condition #2: Evocation should be up by the time we finish burning. We use the custom variable average_burn_length to help estimate when Evocation will be available.
-- actions.variables+=/variable,name=time_until_burn,op=max,value=cooldown.evocation.remains-variable.average_burn_length
-- # Burn condition #3: 2pt20 grants a damage boost with Presence of Mind usage, so we definitely want to stack that with AP.
-- actions.variables+=/variable,name=time_until_burn,op=max,value=cooldown.presence_of_mind.remains,if=set_bonus.tier20_2pc
-- # Burn condition #4: We need an RoP charge if we've actually taken the talent. Check usable_in to see when we'll be able to cast, and ignore the line if we didn't take the talent.
-- actions.variables+=/variable,name=time_until_burn,op=max,value=action.rune_of_power.usable_in,if=talent.rune_of_power.enabled
-- # Burn condition #5: Charged Up allows the 2pt21 buff to be extended during our burn phase.
-- actions.variables+=/variable,name=time_until_burn,op=max,value=cooldown.charged_up.remains,if=talent.charged_up.enabled&set_bonus.tier21_2pc
-- # Boss is gonna die soon. All the above conditions don't really matter. We're just gonna burn our mana until combat ends.
-- actions.variables+=/variable,name=time_until_burn,op=reset,if=target.time_to_die<variable.average_burn_length
