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
  MirrorImage                           = Spell(55342),
  ArcaneBlast                           = Spell(30451),
  Evocation                             = Spell(12051),
  ChargedUp                             = Spell(205032),
  ArcaneChargeBuff                      = Spell(36032),
  NetherTempest                         = Spell(114923),
  NetherTempestDebuff                   = Spell(114923),
  RuneofPowerBuff                       = Spell(116014),
  ArcanePowerBuff                       = Spell(12042),
  RuleofThreesBuff                      = Spell(264774),
  Overpowered                           = Spell(155147),
  LightsJudgment                        = Spell(255647),
  RuneofPower                           = Spell(116011),
  ArcanePower                           = Spell(12042),
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
local VarConserveMana = 60;
local VarTotalBurns = 0;
local VarAverageBurnLength = 0;

HL:RegisterForEvent(function()
  VarTotalBurns = 0
  VarAverageBurnLength = 0
end, "PLAYER_REGEN_ENABLED")

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

Player.ArcaneBurnPhase = {}
local BurnPhase = Player.ArcaneBurnPhase

function BurnPhase:Reset()
  self.state = false
  self.last_start = HL.GetTime()
  self.last_stop = HL.GetTime()
end
BurnPhase:Reset()

function BurnPhase:Start()
  if Player:AffectingCombat() then
    self.state = true
    self.last_start = HL.GetTime()
  end
end

function BurnPhase:Stop()
  self.state = false
  self.last_stop = HL.GetTime()
end

function BurnPhase:On()
  return self.state or (not Player:AffectingCombat() and Player:IsCasting() and ((S.ArcanePower:CooldownRemainsP() == 0 and S.Evocation:CooldownRemainsP() <= VarAverageBurnLength and (Player:ArcaneChargesP() == Player:ArcaneChargesMax() or (S.ChargedUp:IsAvailable() and S.ChargedUp:CooldownRemainsP() == 0)))))
end

function BurnPhase:Duration()
  return self.state and (HL.GetTime() - self.last_start) or 0
end

HL:RegisterForEvent(function()
  BurnPhase:Reset()
end, "PLAYER_REGEN_DISABLED")

local function PresenceOfMindMax ()
  return 2
end

local function ArcaneMissilesProcMax ()
  return 3
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
      if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect 3"; end
    end
    -- summon_arcane_familiar
    if S.SummonArcaneFamiliar:IsCastableP() and Player:BuffDownP(S.SummonArcaneFamiliarBuff) then
      if HR.Cast(S.SummonArcaneFamiliar) then return "summon_arcane_familiar 7"; end
    end
    -- variable,name=conserve_mana,op=set,value=60
    if (true) then
      VarConserveMana = 60
    end
    -- snapshot_stats
    -- mirror_image
    if S.MirrorImage:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.MirrorImage) then return "mirror_image 14"; end
    end
    -- potion
    if I.DeadlyGrace:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.DeadlyGrace) then return "deadly_grace 16"; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsReadyP() then
      if HR.Cast(S.ArcaneBlast) then return "arcane_blast 18"; end
    end
  end
  Burn = function()
    -- variable,name=total_burns,op=add,value=1,if=!burn_phase
    if (not BurnPhase:On()) then
      VarTotalBurns = VarTotalBurns + 1
    end
    -- start_burn_phase,if=!burn_phase
    if (not BurnPhase:On()) then
      BurnPhase:Start()
      return ""
    end
    -- if we're evocating then stop if we have enough mana
    if (bool(VarBurnPhase)) and (Player:IsChanneling(S.Evocation)) and (Player:ManaPercentageP() < 85) then
      if HR.Cast(S.Evocation) then return "Burn - Keep Evocating"; end
    end
    -- stop_burn_phase,if=burn_phase&prev_gcd.1.evocation&target.time_to_die>variable.average_burn_length&burn_phase_duration>0
    if (BurnPhase:On() and Player:PrevGCDP(1, S.Evocation) and Target:TimeToDie() > VarAverageBurnLength and BurnPhase:Duration() > 0) then
      BurnPhase:Stop()
      return ""
    end
    -- charged_up,if=buff.arcane_charge.stack<=1
    if S.ChargedUp:IsCastableP() and (Player:ArcaneChargesP() <= 1) then
      if HR.Cast(S.ChargedUp) then return "charged_up 30"; end
    end
    -- mirror_image
    if S.MirrorImage:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.MirrorImage) then return "mirror_image 34"; end
    end
    -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
    if S.NetherTempest:IsCastableP() and ((Target:DebuffRefreshableCP(S.NetherTempestDebuff) or not Target:DebuffP(S.NetherTempestDebuff)) and Player:ArcaneChargesP() == Player:ArcaneChargesMax() and Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.NetherTempest) then return "nether_tempest 36"; end
    end
    -- arcane_blast,if=buff.rule_of_threes.up&talent.overpowered.enabled&active_enemies<3
    if S.ArcaneBlast:IsReadyP() and (Player:BuffP(S.RuleofThreesBuff) and S.Overpowered:IsAvailable() and Cache.EnemiesCount[40] < 3) then
      if HR.Cast(S.ArcaneBlast) then return "arcane_blast 58"; end
    end
    -- lights_judgment,if=buff.arcane_power.down
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 70"; end
    end
    -- rune_of_power,if=!buff.arcane_power.up&(mana.pct>=50|cooldown.arcane_power.remains=0)&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
    if S.RuneofPower:IsCastableP() and (not Player:BuffP(S.ArcanePowerBuff) and (Player:ManaPercentageP() >= 50 or S.ArcanePower:CooldownRemainsP() == 0) and (Player:ArcaneChargesP() == Player:ArcaneChargesMax())) then
      if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneofPower) then return "rune_of_power 74"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 84"; end
    end
    -- arcane_power
    if S.ArcanePower:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.ArcanePower, Settings.Arcane.GCDasOffGCD.ArcanePower) then return "arcane_power 86"; end
    end
    -- use_items,if=buff.arcane_power.up|target.time_to_die<cooldown.arcane_power.remains
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 89"; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 91"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 93"; end
    end
    -- presence_of_mind,if=buff.rune_of_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time|buff.arcane_power.remains<=buff.presence_of_mind.max_stack*action.arcane_blast.execute_time
    if S.PresenceofMind:IsCastableP() and HR.CDsON() and (Player:BuffRemainsP(S.RuneofPowerBuff) <= PresenceOfMindMax() * S.ArcaneBlast:ExecuteTime() or Player:BuffRemainsP(S.ArcanePowerBuff) <= PresenceOfMindMax() * S.ArcaneBlast:ExecuteTime()) then
      if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind 95"; end
    end
    -- potion,if=buff.arcane_power.up&(buff.berserking.up|buff.blood_fury.up|!(race.troll|race.orc))
    if I.DeadlyGrace:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.ArcanePowerBuff) and (Player:BuffP(S.BerserkingBuff) or Player:BuffP(S.BloodFuryBuff) or not (Player:IsRace("Troll") or Player:IsRace("Orc")))) then
      if HR.CastSuggested(I.DeadlyGrace) then return "deadly_grace 113"; end
    end
    -- arcane_orb,if=buff.arcane_charge.stack=0|(active_enemies<3|(active_enemies<2&talent.resonance.enabled))
    if S.ArcaneOrb:IsCastableP() and (Player:ArcaneChargesP() == 0 or (Cache.EnemiesCount[40] < 3 or (Cache.EnemiesCount[40] < 2 and S.Resonance:IsAvailable()))) then
      if HR.Cast(S.ArcaneOrb) then return "arcane_orb 121"; end
    end
    -- arcane_barrage,if=active_enemies>=3&(buff.arcane_charge.stack=buff.arcane_charge.max_stack)
    if S.ArcaneBarrage:IsCastableP() and (Cache.EnemiesCount[40] >= 3 and (Player:ArcaneChargesP() == Player:ArcaneChargesMax())) then
      if HR.Cast(S.ArcaneBarrage) then return "arcane_barrage 139"; end
    end
    -- arcane_explosion,if=active_enemies>=3
    if S.ArcaneExplosion:IsReadyP() and (Cache.EnemiesCount[10] >= 3) then
      if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion 151"; end
    end
    -- arcane_missiles,if=buff.clearcasting.react&active_enemies<3&(talent.amplification.enabled|(!talent.overpowered.enabled&azerite.arcane_pummeling.rank>=2)|buff.arcane_power.down),chain=1
    if S.ArcaneMissiles:IsCastableP() and (bool(Player:BuffStackP(S.ClearcastingBuff)) and Cache.EnemiesCount[40] < 3 and (S.Amplification:IsAvailable() or (not S.Overpowered:IsAvailable() and S.ArcanePummeling:AzeriteRank() >= 2) or Player:BuffDownP(S.ArcanePowerBuff))) then
      if HR.Cast(S.ArcaneMissiles) then return "arcane_missiles 159"; end
    end
    -- arcane_blast,if=active_enemies<3
    if S.ArcaneBlast:IsReadyP() and (Cache.EnemiesCount[40] < 3) then
      if HR.Cast(S.ArcaneBlast) then return "arcane_blast 177"; end
    end
    -- variable,name=average_burn_length,op=set,value=(variable.average_burn_length*variable.total_burns-variable.average_burn_length+(burn_phase_duration))%variable.total_burns
    if (true) then
      VarAverageBurnLength = (VarAverageBurnLength * VarTotalBurns - VarAverageBurnLength + (BurnPhase:Duration())) / VarTotalBurns
    end
    -- evocation,interrupt_if=mana.pct>=85,interrupt_immediate=1
    if S.Evocation:IsCastableP() then
      if HR.Cast(S.Evocation) then return "evocation 195"; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsCastableP() then
      if HR.Cast(S.ArcaneBarrage) then return "arcane_barrage 197"; end
    end
  end
  Conserve = function()
    -- mirror_image
    if S.MirrorImage:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.MirrorImage) then return "mirror_image 199"; end
    end
    -- charged_up,if=buff.arcane_charge.stack=0
    if S.ChargedUp:IsCastableP() and (Player:ArcaneChargesP() == 0) then
      if HR.Cast(S.ChargedUp) then return "charged_up 201"; end
    end
    -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.rune_of_power.down&buff.arcane_power.down
    if S.NetherTempest:IsCastableP() and ((Target:DebuffRefreshableCP(S.NetherTempestDebuff) or not Target:DebuffP(S.NetherTempestDebuff)) and Player:ArcaneChargesP() == Player:ArcaneChargesMax() and Player:BuffDownP(S.RuneofPowerBuff) and Player:BuffDownP(S.ArcanePowerBuff)) then
      if HR.Cast(S.NetherTempest) then return "nether_tempest 205"; end
    end
    -- arcane_orb,if=buff.arcane_charge.stack<=2&(cooldown.arcane_power.remains>10|active_enemies<=2)
    if S.ArcaneOrb:IsCastableP() and (Player:ArcaneChargesP() <= 2 and (S.ArcanePower:CooldownRemainsP() > 10 or Cache.EnemiesCount[40] <= 2)) then
      if HR.Cast(S.ArcaneOrb) then return "arcane_orb 227"; end
    end
    -- arcane_blast,if=buff.rule_of_threes.up&buff.arcane_charge.stack>3
    if S.ArcaneBlast:IsReadyP() and (Player:BuffP(S.RuleofThreesBuff) and Player:ArcaneChargesP() > 3) then
      if HR.Cast(S.ArcaneBlast) then return "arcane_blast 239"; end
    end
    -- rune_of_power,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&(full_recharge_time<=execute_time|full_recharge_time<=cooldown.arcane_power.remains|target.time_to_die<=cooldown.arcane_power.remains)
    if S.RuneofPower:IsCastableP() and (Player:ArcaneChargesP() == Player:ArcaneChargesMax() and (S.RuneofPower:FullRechargeTimeP() <= S.RuneofPower:ExecuteTime() or S.RuneofPower:FullRechargeTimeP() <= S.ArcanePower:CooldownRemainsP() or Target:TimeToDie() <= S.ArcanePower:CooldownRemainsP())) then
      if HR.Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneofPower) then return "rune_of_power 245"; end
    end
    -- arcane_missiles,if=mana.pct<=95&buff.clearcasting.react&active_enemies<3,chain=1
    if S.ArcaneMissiles:IsCastableP() and (Player:ManaPercentageP() <= 95 and bool(Player:BuffStackP(S.ClearcastingBuff)) and Cache.EnemiesCount[40] < 3) then
      if HR.Cast(S.ArcaneMissiles) then return "arcane_missiles 273"; end
    end
    -- arcane_barrage,if=((buff.arcane_charge.stack=buff.arcane_charge.max_stack)&((mana.pct<=variable.conserve_mana)|(cooldown.arcane_power.remains>cooldown.rune_of_power.full_recharge_time&mana.pct<=variable.conserve_mana+25))|(talent.arcane_orb.enabled&cooldown.arcane_orb.remains<=gcd&cooldown.arcane_power.remains>10))|mana.pct<=(variable.conserve_mana-10)
    if S.ArcaneBarrage:IsCastableP() and (((Player:ArcaneChargesP() == Player:ArcaneChargesMax()) and ((Player:ManaPercentageP() <= VarConserveMana) or (S.ArcanePower:CooldownRemainsP() > S.RuneofPower:FullRechargeTimeP() and Player:ManaPercentageP() <= VarConserveMana + 25)) or (S.ArcaneOrb:IsAvailable() and S.ArcaneOrb:CooldownRemainsP() <= Player:GCD() and S.ArcanePower:CooldownRemainsP() > 10)) or Player:ManaPercentageP() <= (VarConserveMana - 10)) then
      if HR.Cast(S.ArcaneBarrage) then return "arcane_barrage 283"; end
    end
    -- supernova,if=mana.pct<=95
    if S.Supernova:IsCastableP() and (Player:ManaPercentageP() <= 95) then
      if HR.Cast(S.Supernova) then return "supernova 305"; end
    end
    -- arcane_explosion,if=active_enemies>=3&(mana.pct>=variable.conserve_mana|buff.arcane_charge.stack=3)
    if S.ArcaneExplosion:IsReadyP() and (Cache.EnemiesCount[10] >= 3 and (Player:ManaPercentageP() >= VarConserveMana or Player:ArcaneChargesP() == 3)) then
      if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion 307"; end
    end
    -- arcane_blast
    if S.ArcaneBlast:IsReadyP() then
      if HR.Cast(S.ArcaneBlast) then return "arcane_blast 319"; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsCastableP() then
      if HR.Cast(S.ArcaneBarrage) then return "arcane_barrage 321"; end
    end
  end
  Movement = function()
    -- shimmer,if=movement.distance>=10
    if S.Shimmer:IsCastableP() and (movement.distance >= 10) then
      if HR.Cast(S.Shimmer) then return "shimmer 323"; end
    end
    -- blink,if=movement.distance>=10
    if S.Blink:IsCastableP() and (movement.distance >= 10) then
      if HR.Cast(S.Blink) then return "blink 325"; end
    end
    -- presence_of_mind
    if S.PresenceofMind:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind 327"; end
    end
    -- arcane_missiles
    if S.ArcaneMissiles:IsCastableP() then
      if HR.Cast(S.ArcaneMissiles) then return "arcane_missiles 329"; end
    end
    -- arcane_orb
    if S.ArcaneOrb:IsCastableP() then
      if HR.Cast(S.ArcaneOrb) then return "arcane_orb 331"; end
    end
    -- supernova
    if S.Supernova:IsCastableP() then
      if HR.Cast(S.Supernova) then return "supernova 333"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell,if=target.debuff.casting.react
    -- call_action_list,name=burn,if=burn_phase|target.time_to_die<variable.average_burn_length
    if HR.CDsON() and (BurnPhase:On() or Target:TimeToDie() < VarAverageBurnLength) then
      local ShouldReturn = Burn(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=burn,if=(cooldown.arcane_power.remains=0&cooldown.evocation.remains<=variable.average_burn_length&(buff.arcane_charge.stack=buff.arcane_charge.max_stack|(talent.charged_up.enabled&cooldown.charged_up.remains=0&buff.arcane_charge.stack<=1)))
    if HR.CDsON() and ((S.ArcanePower:CooldownRemainsP() == 0 and S.Evocation:CooldownRemainsP() <= VarAverageBurnLength and (Player:ArcaneChargesP() == Player:ArcaneChargesMax() or (S.ChargedUp:IsAvailable() and S.ChargedUp:CooldownRemainsP() == 0 and Player:ArcaneChargesP() <= 1)))) then
      local ShouldReturn = Burn(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=conserve,if=!burn_phase
    if (not BurnPhase:On() or (not HR.CDsON())) then
      local ShouldReturn = Conserve(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=movement
    -- if (true) then
    --   local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    -- end
  end
end

HR.SetAPL(62, APL)
