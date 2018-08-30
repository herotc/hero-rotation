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
Spell.Mage.Fire = {
  ArcaneIntellectBuff                   = Spell(1459),
  ArcaneIntellect                       = Spell(1459),
  MirrorImage                           = Spell(55342),
  Pyroblast                             = Spell(11366),
  BlastWave                             = Spell(157981),
  CombustionBuff                        = Spell(190319),
  FireBlast                             = Spell(108853),
  Meteor                                = Spell(153561),
  Combustion                            = Spell(190319),
  RuneofPowerBuff                       = Spell(116014),
  DragonsBreath                         = Spell(31661),
  AlexstraszasFury                      = Spell(235870),
  HotStreakBuff                         = Spell(48108),
  LivingBomb                            = Spell(44457),
  LightsJudgment                        = Spell(255647),
  RuneofPower                           = Spell(116011),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  Flamestrike                           = Spell(2120),
  FlamePatch                            = Spell(205037),
  PyroclasmBuff                         = Spell(269651),
  HeatingUpBuff                         = Spell(48107),
  PhoenixFlames                         = Spell(257541),
  Scorch                                = Spell(2948),
  SearingTouch                          = Spell(269644),
  Fireball                              = Spell(133),
  Kindling                              = Spell(155148),
  IncantersFlowBuff                     = Spell(1463),
  Preheat                               = Spell(273331),
  PreheatDebuff                         = Spell(273333),
  Firestarter                           = Spell(205026)
};
local S = Spell.Mage.Fire;

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Fire = {
  ProlongedPower                   = Item(142117)
};
local I = Item.Mage.Fire;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Fire = HR.GUISettings.APL.Mage.Fire
};

-- Variables

local EnemyRanges = {40}
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

S.PhoenixFlames:RegisterInFlight();
S.Pyroblast:RegisterInFlight(S.CombustionBuff);
S.Fireball:RegisterInFlight(S.CombustionBuff);

function S.Firestarter:ActiveStatus()
    return (S.Firestarter:IsAvailable() and (Target:HealthPercentage() > 90)) and 1 or 0
end

function S.Firestarter:ActiveRemains()
    return S.Firestarter:IsAvailable() and ((Target:HealthPercentage() > 90) and Target:TimeToX(90, 3) or 0)
end
--- ======= ACTION LISTS =======
local function APL()
  local Precombat, ActiveTalents, CombustionPhase, RopPhase, StandardRotation
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- arcane_intellect
    if S.ArcaneIntellect:IsCastableP() and Player:BuffDownP(S.ArcaneIntellectBuff) then
      if HR.Cast(S.ArcaneIntellect) then return ""; end
    end
    -- snapshot_stats
    -- mirror_image
    if S.MirrorImage:IsCastableP() then
      if HR.Cast(S.MirrorImage) then return ""; end
    end
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- pyroblast
    if S.Pyroblast:IsCastableP() and Everyone.TargetIsValid() then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
  end
  ActiveTalents = function()
    -- blast_wave,if=(buff.combustion.down)|(buff.combustion.up&action.fire_blast.charges<1)
    if S.BlastWave:IsCastableP() and ((Player:BuffDownP(S.CombustionBuff)) or (Player:BuffP(S.CombustionBuff) and S.FireBlast:ChargesP() < 1)) then
      if HR.Cast(S.BlastWave) then return ""; end
    end
    -- meteor,if=cooldown.combustion.remains>40|(cooldown.combustion.remains>target.time_to_die)|buff.rune_of_power.up|firestarter.active
    if S.Meteor:IsCastableP() and (S.Combustion:CooldownRemainsP() > 40 or (S.Combustion:CooldownRemainsP() > Target:TimeToDie()) or Player:BuffP(S.RuneofPowerBuff) or bool(S.Firestarter:ActiveStatus())) then
      if HR.Cast(S.Meteor) then return ""; end
    end
    -- dragons_breath,if=talent.alexstraszas_fury.enabled&!buff.hot_streak.react
    if S.DragonsBreath:IsCastableP() and (S.AlexstraszasFury:IsAvailable() and not bool(Player:BuffStackP(S.HotStreakBuff))) then
      if HR.Cast(S.DragonsBreath) then return ""; end
    end
    -- living_bomb,if=active_enemies>1&buff.combustion.down
    if S.LivingBomb:IsCastableP() and (Cache.EnemiesCount[40] > 1 and Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.LivingBomb) then return ""; end
    end
  end
  CombustionPhase = function()
    -- lights_judgment,if=buff.combustion.down
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.LightsJudgment) then return ""; end
    end
    -- rune_of_power,if=buff.combustion.down
    if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return ""; end
    end
    -- call_action_list,name=active_talents
    if (true) then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- combustion
    if S.Combustion:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return ""; end
    end
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- use_items
    -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>2)|active_enemies>6)&buff.hot_streak.react
    if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and Cache.EnemiesCount[40] > 2) or Cache.EnemiesCount[40] > 6) and bool(Player:BuffStackP(S.HotStreakBuff))) then
      if HR.Cast(S.Flamestrike) then return ""; end
    end
    -- pyroblast,if=buff.pyroclasm.react&buff.combustion.remains>execute_time
    if S.Pyroblast:IsCastableP() and (bool(Player:BuffStackP(S.PyroclasmBuff)) and Player:BuffRemainsP(S.CombustionBuff) > S.Pyroblast:ExecuteTime()) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react
    if S.Pyroblast:IsCastableP() and (bool(Player:BuffStackP(S.HotStreakBuff))) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- fire_blast,if=buff.heating_up.react
    if S.FireBlast:IsCastableP() and (bool(Player:BuffStackP(S.HeatingUpBuff))) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- phoenix_flames
    if S.PhoenixFlames:IsCastableP() then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- scorch,if=buff.combustion.remains>cast_time
    if S.Scorch:IsCastableP() and (Player:BuffRemainsP(S.CombustionBuff) > S.Scorch:CastTime()) then
      if HR.Cast(S.Scorch) then return ""; end
    end
    -- dragons_breath,if=!buff.hot_streak.react&action.fire_blast.charges<1
    if S.DragonsBreath:IsCastableP() and (not bool(Player:BuffStackP(S.HotStreakBuff)) and S.FireBlast:ChargesP() < 1) then
      if HR.Cast(S.DragonsBreath) then return ""; end
    end
    -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled
    if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Scorch) then return ""; end
    end
  end
  RopPhase = function()
    -- rune_of_power
    if S.RuneofPower:IsCastableP() then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return ""; end
    end
    -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>4)&buff.hot_streak.react
    if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and Cache.EnemiesCount[40] > 1) or Cache.EnemiesCount[40] > 4) and bool(Player:BuffStackP(S.HotStreakBuff))) then
      if HR.Cast(S.Flamestrike) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react
    if S.Pyroblast:IsCastableP() and (bool(Player:BuffStackP(S.HotStreakBuff))) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- call_action_list,name=active_talents
    if (true) then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- pyroblast,if=buff.pyroclasm.react&execute_time<buff.pyroclasm.remains&buff.rune_of_power.remains>cast_time
    if S.Pyroblast:IsCastableP() and (bool(Player:BuffStackP(S.PyroclasmBuff)) and S.Pyroblast:ExecuteTime() < Player:BuffRemainsP(S.PyroclasmBuff) and Player:BuffRemainsP(S.RuneofPowerBuff) > S.Pyroblast:CastTime()) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- fire_blast,if=!prev_off_gcd.fire_blast&buff.heating_up.react&firestarter.active&charges_fractional>1.7
    if S.FireBlast:IsCastableP() and (not Player:PrevOffGCDP(1, S.FireBlast) and bool(Player:BuffStackP(S.HeatingUpBuff)) and bool(S.Firestarter:ActiveStatus()) and S.FireBlast:ChargesFractional() > 1.7) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- phoenix_flames,if=!prev_gcd.1.phoenix_flames&charges_fractional>2.7&firestarter.active
    if S.PhoenixFlames:IsCastableP() and (not Player:PrevGCDP(1, S.PhoenixFlames) and S.PhoenixFlames:ChargesFractional() > 2.7 and bool(S.Firestarter:ActiveStatus())) then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- fire_blast,if=!prev_off_gcd.fire_blast&!firestarter.active
    if S.FireBlast:IsCastableP() and (not Player:PrevOffGCDP(1, S.FireBlast) and not bool(S.Firestarter:ActiveStatus())) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- phoenix_flames,if=!prev_gcd.1.phoenix_flames
    if S.PhoenixFlames:IsCastableP() and (not Player:PrevGCDP(1, S.PhoenixFlames)) then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- scorch,if=target.health.pct<=30&talent.searing_touch.enabled
    if S.Scorch:IsCastableP() and (Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Scorch) then return ""; end
    end
    -- dragons_breath,if=active_enemies>2
    if S.DragonsBreath:IsCastableP() and (Cache.EnemiesCount[40] > 2) then
      if HR.Cast(S.DragonsBreath) then return ""; end
    end
    -- flamestrike,if=(talent.flame_patch.enabled&active_enemies>2)|active_enemies>5
    if S.Flamestrike:IsCastableP() and ((S.FlamePatch:IsAvailable() and Cache.EnemiesCount[40] > 2) or Cache.EnemiesCount[40] > 5) then
      if HR.Cast(S.Flamestrike) then return ""; end
    end
    -- fireball
    if S.Fireball:IsCastableP() then
      if HR.Cast(S.Fireball) then return ""; end
    end
  end
  StandardRotation = function()
    -- flamestrike,if=((talent.flame_patch.enabled&active_enemies>1)|active_enemies>4)&buff.hot_streak.react
    if S.Flamestrike:IsCastableP() and (((S.FlamePatch:IsAvailable() and Cache.EnemiesCount[40] > 1) or Cache.EnemiesCount[40] > 4) and bool(Player:BuffStackP(S.HotStreakBuff))) then
      if HR.Cast(S.Flamestrike) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react&buff.hot_streak.remains<action.fireball.execute_time
    if S.Pyroblast:IsCastableP() and (bool(Player:BuffStackP(S.HotStreakBuff)) and Player:BuffRemainsP(S.HotStreakBuff) < S.Fireball:ExecuteTime()) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react&firestarter.active&!talent.rune_of_power.enabled
    if S.Pyroblast:IsCastableP() and (bool(Player:BuffStackP(S.HotStreakBuff)) and bool(S.Firestarter:ActiveStatus()) and not S.RuneofPower:IsAvailable()) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- phoenix_flames,if=charges_fractional>2.7&active_enemies>2
    if S.PhoenixFlames:IsCastableP() and (S.PhoenixFlames:ChargesFractional() > 2.7 and Cache.EnemiesCount[40] > 2) then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react&(!prev_gcd.1.pyroblast|action.pyroblast.in_flight)
    if S.Pyroblast:IsCastableP() and (bool(Player:BuffStackP(S.HotStreakBuff)) and (not Player:PrevGCDP(1, S.Pyroblast) or S.Pyroblast:InFlight())) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.hot_streak.react&target.health.pct<=30&talent.searing_touch.enabled
    if S.Pyroblast:IsCastableP() and (bool(Player:BuffStackP(S.HotStreakBuff)) and Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- pyroblast,if=buff.pyroclasm.react&execute_time<buff.pyroclasm.remains
    if S.Pyroblast:IsCastableP() and (bool(Player:BuffStackP(S.PyroclasmBuff)) and S.Pyroblast:ExecuteTime() < Player:BuffRemainsP(S.PyroclasmBuff)) then
      if HR.Cast(S.Pyroblast) then return ""; end
    end
    -- call_action_list,name=active_talents
    if (true) then
      local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
    end
    -- fire_blast,if=!talent.kindling.enabled&buff.heating_up.react&(!talent.rune_of_power.enabled|charges_fractional>1.4|cooldown.combustion.remains<40)&(3-charges_fractional)*(12*spell_haste)<cooldown.combustion.remains+3|target.time_to_die<4
    if S.FireBlast:IsCastableP() and (not S.Kindling:IsAvailable() and bool(Player:BuffStackP(S.HeatingUpBuff)) and (not S.RuneofPower:IsAvailable() or S.FireBlast:ChargesFractional() > 1.4 or S.Combustion:CooldownRemainsP() < 40) and (3 - S.FireBlast:ChargesFractional()) * (12 * Player:SpellHaste()) < S.Combustion:CooldownRemainsP() + 3 or Target:TimeToDie() < 4) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- fire_blast,if=talent.kindling.enabled&buff.heating_up.react&(!talent.rune_of_power.enabled|charges_fractional>1.5|cooldown.combustion.remains<40)&(3-charges_fractional)*(18*spell_haste)<cooldown.combustion.remains+3|target.time_to_die<4
    if S.FireBlast:IsCastableP() and (S.Kindling:IsAvailable() and bool(Player:BuffStackP(S.HeatingUpBuff)) and (not S.RuneofPower:IsAvailable() or S.FireBlast:ChargesFractional() > 1.5 or S.Combustion:CooldownRemainsP() < 40) and (3 - S.FireBlast:ChargesFractional()) * (18 * Player:SpellHaste()) < S.Combustion:CooldownRemainsP() + 3 or Target:TimeToDie() < 4) then
      if HR.Cast(S.FireBlast) then return ""; end
    end
    -- phoenix_flames,if=(buff.combustion.up|buff.rune_of_power.up|buff.incanters_flow.stack>3|talent.mirror_image.enabled)&(4-charges_fractional)*13<cooldown.combustion.remains+5|target.time_to_die<10
    if S.PhoenixFlames:IsCastableP() and ((Player:BuffP(S.CombustionBuff) or Player:BuffP(S.RuneofPowerBuff) or Player:BuffStackP(S.IncantersFlowBuff) > 3 or S.MirrorImage:IsAvailable()) and (4 - S.PhoenixFlames:ChargesFractional()) * 13 < S.Combustion:CooldownRemainsP() + 5 or Target:TimeToDie() < 10) then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- phoenix_flames,if=(buff.combustion.up|buff.rune_of_power.up)&(4-charges_fractional)*30<cooldown.combustion.remains+5
    if S.PhoenixFlames:IsCastableP() and ((Player:BuffP(S.CombustionBuff) or Player:BuffP(S.RuneofPowerBuff)) and (4 - S.PhoenixFlames:ChargesFractional()) * 30 < S.Combustion:CooldownRemainsP() + 5) then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- phoenix_flames,if=charges_fractional>2.5&cooldown.combustion.remains>23
    if S.PhoenixFlames:IsCastableP() and (S.PhoenixFlames:ChargesFractional() > 2.5 and S.Combustion:CooldownRemainsP() > 23) then
      if HR.Cast(S.PhoenixFlames) then return ""; end
    end
    -- scorch,if=(target.health.pct<=30&talent.searing_touch.enabled)|(azerite.preheat.enabled&debuff.preheat.down)
    if S.Scorch:IsCastableP() and ((Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable()) or (S.Preheat:AzeriteEnabled() and Target:DebuffDownP(S.PreheatDebuff))) then
      if HR.Cast(S.Scorch) then return ""; end
    end
    -- fireball
    if S.Fireball:IsCastableP() then
      if HR.Cast(S.Fireball) then return ""; end
    end
    -- scorch
    if S.Scorch:IsCastableP() then
      if HR.Cast(S.Scorch) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell,if=target.debuff.casting.react
    -- time_warp,if=time=0&buff.bloodlust.down
    -- mirror_image,if=buff.combustion.down
    if S.MirrorImage:IsCastableP() and (Player:BuffDownP(S.CombustionBuff)) then
      if HR.Cast(S.MirrorImage) then return ""; end
    end
    -- rune_of_power,if=firestarter.active&action.rune_of_power.charges=2|cooldown.combustion.remains>40&buff.combustion.down&!talent.kindling.enabled|target.time_to_die<11|talent.kindling.enabled&(charges_fractional>1.8|time<40)&cooldown.combustion.remains>40
    if S.RuneofPower:IsCastableP() and (bool(S.Firestarter:ActiveStatus()) and S.RuneofPower:ChargesP() == 2 or S.Combustion:CooldownRemainsP() > 40 and Player:BuffDownP(S.CombustionBuff) and not S.Kindling:IsAvailable() or Target:TimeToDie() < 11 or S.Kindling:IsAvailable() and (S.RuneofPower:ChargesFractional() > 1.8 or HL.CombatTime() < 40) and S.Combustion:CooldownRemainsP() > 40) then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return ""; end
    end
    -- rune_of_power,if=buff.pyroclasm.react&(cooldown.combustion.remains>40|action.rune_of_power.charges>1)
    if S.RuneofPower:IsCastableP() and (bool(Player:BuffStackP(S.PyroclasmBuff)) and (S.Combustion:CooldownRemainsP() > 40 or S.RuneofPower:ChargesP() > 1)) then
      if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneofPower) then return ""; end
    end
    -- call_action_list,name=combustion_phase,if=cooldown.combustion.remains<=action.rune_of_power.cast_time+(!talent.kindling.enabled*gcd)&(!talent.firestarter.enabled|!firestarter.active|active_enemies>=4|active_enemies>=2&talent.flame_patch.enabled)|buff.combustion.up
    if HR.CDsON() and (S.Combustion:CooldownRemainsP() <= S.RuneofPower:CastTime() + (num(not S.Kindling:IsAvailable()) * Player:GCD()) and (not S.Firestarter:IsAvailable() or not bool(S.Firestarter:ActiveStatus()) or Cache.EnemiesCount[40] >= 4 or Cache.EnemiesCount[40] >= 2 and S.FlamePatch:IsAvailable()) or Player:BuffP(S.CombustionBuff)) then
      local ShouldReturn = CombustionPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=rop_phase,if=buff.rune_of_power.up&buff.combustion.down
    if (Player:BuffP(S.RuneofPowerBuff) and Player:BuffDownP(S.CombustionBuff)) then
      local ShouldReturn = RopPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=standard_rotation
    if (true) then
      local ShouldReturn = StandardRotation(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

HR.SetAPL(63, APL)
