--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local AC     = HeroLib
local Cache  = HeroCache
local Unit   = AC.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = AC.Spell
local Item   = AC.Item
-- AethysRotation
local AR     = AethysRotation

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Mage then Spell.Mage = {} end
Spell.Mage.Frost = {
  ArcaneIntellect                       = Spell(1459),
  WaterElemental                        = Spell(31687),
  MirrorImage                           = Spell(55342),
  Frostbolt                             = Spell(116),
  FrozenOrb                             = Spell(84714),
  Blizzard                              = Spell(190356),
  CometStorm                            = Spell(153595),
  IceNova                               = Spell(157997),
  Flurry                                = Spell(44614),
  Ebonbolt                              = Spell(257537),
  BrainFreezeBuff                       = Spell(190446),
  GlacialSpike                          = Spell(199786),
  IciclesBuff                           = Spell(205473),
  IceLance                              = Spell(30455),
  FingersofFrostBuff                    = Spell(44544),
  RayofFrost                            = Spell(205021),
  ConeofCold                            = Spell(120),
  RuneofPower                           = Spell(116011),
  IcyVeins                              = Spell(12472),
  IcyVeinsBuff                          = Spell(12472),
  -- UseItems                              = Spell(),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Blink                                 = Spell(1953),
  IceFloes                              = Spell(108839),
  IceFloesBuff                          = Spell(108839),
  WintersChillDebuff                    = Spell(228358),
  ZannesuJourneyBuff                    = Spell(206397),
  Counterspell                          = Spell(2139),
  TimeWarp                              = Spell(80353),
  ExhaustionBuff                        = Spell(57723)
};
local S = Spell.Mage.Frost;

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Frost = {
  ProlongedPower                   = Item(142117),
  ShardoftheExodar                 = Item(132410)
};
local I = Item.Mage.Frost;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = AR.Commons.Everyone;
local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.Mage.Commons,
  Frost = AR.GUISettings.APL.Mage.Frost
};

-- Variables

local EnemyRanges = {35}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    AC.GetEnemies(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

--- ======= ACTION LISTS =======
local function APL()
  UpdateRanges()
  local function Precombat()
    -- flask
    -- food
    -- augmentation
    -- arcane_intellect
    if S.ArcaneIntellect:IsCastableP() and not Player:BuffP(S.ArcaneIntellect) and (true) then
      if AR.Cast(S.ArcaneIntellect) then return ""; end
    end
    -- water_elemental
    if S.WaterElemental:IsCastableP() and not Pet:IsActive() and (true) then
      if AR.Cast(S.WaterElemental) then return ""; end
    end
    -- snapshot_stats
    -- mirror_image
    if S.MirrorImage:IsCastableP() and (true) then
      if AR.Cast(S.MirrorImage) then return ""; end
    end
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (true) then
      if AR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- frostbolt
    if S.Frostbolt:IsCastableP() and (true) then
      if AR.Cast(S.Frostbolt) then return ""; end
    end
  end
  local function Aoe()
    -- frozen_orb
    if S.FrozenOrb:IsCastableP() and (true) then
      if AR.Cast(S.FrozenOrb) then return ""; end
    end
    -- blizzard
    if S.Blizzard:IsCastableP() and (true) then
      if AR.Cast(S.Blizzard) then return ""; end
    end
    -- comet_storm
    if S.CometStorm:IsCastableP() and (true) then
      if AR.Cast(S.CometStorm) then return ""; end
    end
    -- ice_nova
    if S.IceNova:IsCastableP() and (true) then
      if AR.Cast(S.IceNova) then return ""; end
    end
    -- flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt&(!talent.glacial_spike.enabled|buff.icicles.stack<=4))
    if S.Flurry:IsCastableP() and (Player:PrevGCDP(1, S.Ebonbolt) or bool(Player:BuffStackP(S.BrainFreezeBuff)) and (Player:PrevGCDP(1, S.GlacialSpike) or Player:PrevGCDP(1, S.Frostbolt) and (not S.GlacialSpike:IsAvailable() or Player:BuffStackP(S.IciclesBuff) <= 4))) then
      if AR.Cast(S.Flurry) then return ""; end
    end
    -- ice_lance,if=buff.fingers_of_frost.react
    if S.IceLance:IsCastableP() and (bool(Player:BuffStackP(S.FingersofFrostBuff))) then
      if AR.Cast(S.IceLance) then return ""; end
    end
    -- ebonbolt
    if S.Ebonbolt:IsCastableP() and (true) then
      if AR.Cast(S.Ebonbolt) then return ""; end
    end
    -- glacial_spike,if=buff.brain_freeze.react
    if S.GlacialSpike:IsCastableP() and (bool(Player:BuffStackP(S.BrainFreezeBuff))) then
      if AR.Cast(S.GlacialSpike) then return ""; end
    end
    -- ray_of_frost
    if S.RayofFrost:IsCastableP() and (true) then
      if AR.Cast(S.RayofFrost) then return ""; end
    end
    -- frostbolt
    if S.Frostbolt:IsCastableP() and (true) then
      if AR.Cast(S.Frostbolt) then return ""; end
    end
    -- call_action_list,name=movement
    if (true) then
      local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    end
    -- cone_of_cold
    if S.ConeofCold:IsCastableP() and (true) then
      if AR.Cast(S.ConeofCold) then return ""; end
    end
    -- ice_lance
    if S.IceLance:IsCastableP() and (true) then
      if AR.Cast(S.IceLance) then return ""; end
    end
  end
  local function Cooldowns()
    -- rune_of_power,if=cooldown.icy_veins.remains<cast_time|charges_fractional>1.9&cooldown.icy_veins.remains>10|buff.icy_veins.up|target.time_to_die+5<charges_fractional*10
    if S.RuneofPower:IsCastableP() and (S.IcyVeins:CooldownRemainsP() < S.RuneofPower:CastTime() or S.RuneofPower:ChargesFractional() > 1.9 and S.IcyVeins:CooldownRemainsP() > 10 or Player:BuffP(S.IcyVeinsBuff) or Target:TimeToDie() + 5 < S.RuneofPower:ChargesFractional() * 10) then
      if AR.Cast(S.RuneofPower) then return ""; end
    end
    -- potion,if=cooldown.icy_veins.remains<1|target.time_to_die<70
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (S.IcyVeins:CooldownRemainsP() < 1 or Target:TimeToDie() < 70) then
      if AR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- icy_veins
    if S.IcyVeins:IsCastableP() and (true) then
      if AR.Cast(S.IcyVeins) then return ""; end
    end
    -- mirror_image
    if S.MirrorImage:IsCastableP() and (true) then
      if AR.Cast(S.MirrorImage) then return ""; end
    end
    -- -- use_items
    -- if S.UseItems:IsCastableP() and (true) then
    --   if AR.Cast(S.UseItems) then return ""; end
    -- end
    -- blood_fury
    if S.BloodFury:IsCastableP() and AR.CDsON() and (true) then
      if AR.Cast(S.BloodFury, Settings.Frost.OffGCDasOffGCD.BloodFury) then return ""; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and AR.CDsON() and (true) then
      if AR.Cast(S.Berserking, Settings.Frost.OffGCDasOffGCD.Berserking) then return ""; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastableP() and AR.CDsON() and (true) then
      if AR.Cast(S.ArcaneTorrent, Settings.Frost.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
    end
    -- lights_judgment
    if S.LightsJudgment:IsCastableP() and (true) then
      if AR.Cast(S.LightsJudgment) then return ""; end
    end
  end
  local function Movement()
    -- blink,if=movement.distance>10
    if S.Blink:IsCastableP() and (movement.distance > 10) then
      if AR.Cast(S.Blink) then return ""; end
    end
    -- ice_floes,if=buff.ice_floes.down
    if S.IceFloes:IsCastableP() and (Player:BuffDownP(S.IceFloesBuff)) then
      if AR.Cast(S.IceFloes) then return ""; end
    end
  end
  local function Single()
    -- ice_nova,if=debuff.winters_chill.up
    if S.IceNova:IsCastableP() and (Target:DebuffP(S.WintersChillDebuff)) then
      if AR.Cast(S.IceNova) then return ""; end
    end
    -- flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt&(!talent.glacial_spike.enabled|buff.icicles.stack<=4))
    if S.Flurry:IsCastableP() and (Player:PrevGCDP(1, S.Ebonbolt) or bool(Player:BuffStackP(S.BrainFreezeBuff)) and (Player:PrevGCDP(1, S.GlacialSpike) or Player:PrevGCDP(1, S.Frostbolt) and (not S.GlacialSpike:IsAvailable() or Player:BuffStackP(S.IciclesBuff) <= 4))) then
      if AR.Cast(S.Flurry) then return ""; end
    end
    -- frozen_orb,if=set_bonus.tier20_2pc&buff.fingers_of_frost.react<2
    if S.FrozenOrb:IsCastableP() and (AC.Tier20_2Pc and Player:BuffStackP(S.FingersofFrostBuff) < 2) then
      if AR.Cast(S.FrozenOrb) then return ""; end
    end
    -- blizzard,if=active_enemies>1&cast_time=0&buff.fingers_of_frost.react<2
    if S.Blizzard:IsCastableP() and (Cache.EnemiesCount[35] > 1 and S.Blizzard:CastTime() == 0 and Player:BuffStackP(S.FingersofFrostBuff) < 2) then
      if AR.Cast(S.Blizzard) then return ""; end
    end
    -- ice_lance,if=buff.fingers_of_frost.react
    if S.IceLance:IsCastableP() and (bool(Player:BuffStackP(S.FingersofFrostBuff))) then
      if AR.Cast(S.IceLance) then return ""; end
    end
    -- ebonbolt
    if S.Ebonbolt:IsCastableP() and (true) then
      if AR.Cast(S.Ebonbolt) then return ""; end
    end
    -- frozen_orb
    if S.FrozenOrb:IsCastableP() and (true) then
      if AR.Cast(S.FrozenOrb) then return ""; end
    end
    -- comet_storm
    if S.CometStorm:IsCastableP() and (true) then
      if AR.Cast(S.CometStorm) then return ""; end
    end
    -- ice_nova
    if S.IceNova:IsCastableP() and (true) then
      if AR.Cast(S.IceNova) then return ""; end
    end
    -- blizzard,if=active_enemies>1|buff.zannesu_journey.stack=5&buff.zannesu_journey.remains>cast_time
    if S.Blizzard:IsCastableP() and (Cache.EnemiesCount[35] > 1 or Player:BuffStackP(S.ZannesuJourneyBuff) == 5 and Player:BuffRemainsP(S.ZannesuJourneyBuff) > S.Blizzard:CastTime()) then
      if AR.Cast(S.Blizzard) then return ""; end
    end
    -- glacial_spike,if=buff.brain_freeze.react
    if S.GlacialSpike:IsCastableP() and (bool(Player:BuffStackP(S.BrainFreezeBuff))) then
      if AR.Cast(S.GlacialSpike) then return ""; end
    end
    -- ray_of_frost
    if S.RayofFrost:IsCastableP() and (true) then
      if AR.Cast(S.RayofFrost) then return ""; end
    end
    -- frostbolt
    if S.Frostbolt:IsCastableP() and (true) then
      if AR.Cast(S.Frostbolt) then return ""; end
    end
    -- call_action_list,name=movement
    if (true) then
      local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    end
    -- ice_lance
    if S.IceLance:IsCastableP() and (true) then
      if AR.Cast(S.IceLance) then return ""; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  -- counterspell
  if S.Counterspell:IsCastableP() and (true) and Target:IsInterruptible() and Settings.General.InterruptEnabled then
   if AR.Cast(S.Counterspell) then return ""; end
  end
  -- ice_lance,if=!buff.fingers_of_frost.react&prev_gcd.1.flurry
  if S.IceLance:IsCastableP() and (not bool(Player:BuffStackP(S.FingersofFrostBuff)) and Player:PrevGCDP(1, S.Flurry)) then
    if AR.Cast(S.IceLance) then return ""; end
  end
  -- time_warp,if=buff.bloodlust.down&(buff.exhaustion.down|equipped.shard_of_the_exodar)&(cooldown.icy_veins.remains<1|target.time_to_die<50)
  if S.TimeWarp:IsCastableP() and (Player:HasNotHeroism() and (Player:BuffDownP(S.ExhaustionBuff) or I.ShardoftheExodar:IsEquipped()) and (S.IcyVeins:CooldownRemainsP() < 1 or Target:TimeToDie() < 50)) then
    if AR.Cast(S.TimeWarp) then return ""; end
  end
  -- call_action_list,name=cooldowns
  if (true) then
    local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=aoe,if=active_enemies>=4
  if (Cache.EnemiesCount[35] >= 4) then
    local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=single
  if (true) then
    local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
  end
end

AR.SetAPL(64, APL)
