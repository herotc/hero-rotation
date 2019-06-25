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
Spell.Mage.Frost = {
  ArcaneIntellectBuff                   = Spell(1459),
  ArcaneIntellect                       = Spell(1459),
  SummonWaterElemental                  = Spell(31687),
  MirrorImage                           = Spell(55342),
  Frostbolt                             = Spell(116),
  FrozenOrb                             = Spell(84714),
  Blizzard                              = Spell(190356),
  CometStorm                            = Spell(153595),
  IceNova                               = Spell(157997),
  Flurry                                = Spell(44614),
  Ebonbolt                              = Spell(257537),
  BrainFreezeBuff                       = Spell(190446),
  IciclesBuff                           = Spell(205473),
  GlacialSpike                          = Spell(199786),
  IceLance                              = Spell(30455),
  FingersofFrostBuff                    = Spell(44544),
  RayofFrost                            = Spell(205021),
  ConeofCold                            = Spell(120),
  IcyVeins                              = Spell(12472),
  RuneofPower                           = Spell(116011),
  RuneofPowerBuff                       = Spell(116014),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  Shimmer                               = Spell(212653),
  Blink                                 = Spell(1953),
  IceFloes                              = Spell(108839),
  IceFloesBuff                          = Spell(108839),
  WintersChillDebuff                    = Spell(228358),
  GlacialSpikeBuff                      = Spell(199844),
  SplittingIce                          = Spell(56377),
  FreezingRain                          = Spell(240555),
  Counterspell                          = Spell(2139),
  BloodOfTheEnemy                       = Spell(297108),
  BloodOfTheEnemy2                      = Spell(298273),
  BloodOfTheEnemy3                      = Spell(298277),
  MemoryOfLucidDreams                   = Spell(298357),
  MemoryOfLucidDreams2                  = Spell(299372),
  MemoryOfLucidDreams3                  = Spell(299374),
  PurifyingBlast                        = Spell(295337),
  PurifyingBlast2                       = Spell(299345),
  PurifyingBlast3                       = Spell(299347),
  RippleInSpace                         = Spell(302731),
  RippleInSpace2                        = Spell(302982),
  RippleInSpace3                        = Spell(302983),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlame2                    = Spell(299349),
  ConcentratedFlame3                    = Spell(299353),
  TheUnboundForce                       = Spell(298452),
  TheUnboundForce2                      = Spell(299376),
  TheUnboundForce3                      = Spell(299378),
  RecklessForce                         = Spell(302932),
  WorldveinResonance                    = Spell(295186),
  WorldveinResonance2                   = Spell(298628),
  WorldveinResonance3                   = Spell(299334),
  FocusedAzeriteBeam                    = Spell(295258),
  FocusedAzeriteBeam2                   = Spell(299336),
  FocusedAzeriteBeam3                   = Spell(299338)
};
local S = Spell.Mage.Frost;

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Frost = {
  ProlongedPower                   = Item(142117),
  TidestormCodex                   = Item(165576)
};
local I = Item.Mage.Frost;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Frost = HR.GUISettings.APL.Mage.Frost
};

local EnemyRanges = {35, 10}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function GetEnemiesCount(range)
  -- Unit Update - Update differently depending on if splash data is being used
  if HR.AoEON() then
    if Settings.Frost.UseSplashData then
      HL.GetEnemies(range, nil, true, Target)
      return Cache.EnemiesCount[range]
    else
      UpdateRanges()
      Everyone.AoEToggleEnemiesUpdate()
      return Cache.EnemiesCount[40]
    end
  else
    return 1
  end
end

S.FrozenOrb:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

S.FrozenOrb.EffectID = 84721
S.Frostbolt:RegisterInFlight()

local function DetermineEssenceRanks()
  S.BloodOfTheEnemy = S.BloodOfTheEnemy2:IsAvailable() and S.BloodOfTheEnemy2 or S.BloodOfTheEnemy
  S.BloodOfTheEnemy = S.BloodOfTheEnemy3:IsAvailable() and S.BloodOfTheEnemy3 or S.BloodOfTheEnemy
  S.MemoryOfLucidDreams = S.MemoryOfLucidDreams2:IsAvailable() and S.MemoryOfLucidDreams2 or S.MemoryOfLucidDreams
  S.MemoryOfLucidDreams = S.MemoryOfLucidDreams3:IsAvailable() and S.MemoryOfLucidDreams3 or S.MemoryOfLucidDreams
  S.PurifyingBlast = S.PurifyingBlast2:IsAvailable() and S.PurifyingBlast2 or S.PurifyingBlast
  S.PurifyingBlast = S.PurifyingBlast3:IsAvailable() and S.PurifyingBlast3 or S.PurifyingBlast
  S.RippleInSpace = S.RippleInSpace2:IsAvailable() and S.RippleInSpace2 or S.RippleInSpace
  S.RippleInSpace = S.RippleInSpace3:IsAvailable() and S.RippleInSpace3 or S.RippleInSpace
  S.ConcentratedFlame = S.ConcentratedFlame2:IsAvailable() and S.ConcentratedFlame2 or S.ConcentratedFlame
  S.ConcentratedFlame = S.ConcentratedFlame3:IsAvailable() and S.ConcentratedFlame3 or S.ConcentratedFlame
  S.TheUnboundForce = S.TheUnboundForce2:IsAvailable() and S.TheUnboundForce2 or S.TheUnboundForce
  S.TheUnboundForce = S.TheUnboundForce3:IsAvailable() and S.TheUnboundForce3 or S.TheUnboundForce
  S.WorldveinResonance = S.WorldveinResonance2:IsAvailable() and S.WorldveinResonance2 or S.WorldveinResonance
  S.WorldveinResonance = S.WorldveinResonance3:IsAvailable() and S.WorldveinResonance3 or S.WorldveinResonance
  S.FocusedAzeriteBeam = S.FocusedAzeriteBeam2:IsAvailable() and S.FocusedAzeriteBeam2 or S.FocusedAzeriteBeam
  S.FocusedAzeriteBeam = S.FocusedAzeriteBeam3:IsAvailable() and S.FocusedAzeriteBeam3 or S.FocusedAzeriteBeam
end

HL.RegisterNucleusAbility(84714, 8, 6)               -- Frost Orb
HL.RegisterNucleusAbility(190356, 8, 6)              -- Blizzard
HL.RegisterNucleusAbility(153595, 8, 6)              -- Comet Storm
HL.RegisterNucleusAbility(120, 12, 6)                -- Cone of Cold

--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Aoe, Cooldowns, Movement, Single, TalentRop, Essences
  local BlinkAny = S.Shimmer:IsAvailable() and S.Shimmer or S.Blink
  EnemiesCount = GetEnemiesCount(8)
  Precombat = function()
    DetermineEssenceRanks()
    -- flask
    -- food
    -- augmentation
    -- arcane_intellect
    if S.ArcaneIntellect:IsCastableP() and Player:BuffDownP(S.ArcaneIntellectBuff, true) then
      if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect 3"; end
    end
    -- summon_water_elemental
    if S.SummonWaterElemental:IsCastableP() then
      if HR.Cast(S.SummonWaterElemental) then return "summon_water_elemental 7"; end
    end
    -- snapshot_stats
    if Everyone.TargetIsValid() then
      -- mirror_image
      if S.MirrorImage:IsCastableP() and HR.CDsON() then
        if HR.Cast(S.MirrorImage, Settings.Frost.GCDasOffGCD.MirrorImage) then return "mirror_image 10"; end
      end
      -- potion
      if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.ProlongedPower) then return "prolonged_power 12"; end
      end
      -- frostbolt
      if S.Frostbolt:IsCastableP() then
        if HR.Cast(S.Frostbolt) then return "frostbolt 14"; end
      end
    end
  end
  Essences = function()
    -- focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastableP() then
      if HR.Cast(S.FocusedAzeriteBeam) then return "focused_azerite_beam"; end
    end
    -- memory_of_lucid_dreams,if=buff.icicles.stack<2
    if S.MemoryOfLucidDreams:IsCastableP() and (Player:BuffStackP(S.IciclesBuff) < 2) then
      if HR.Cast(S.MemoryOfLucidDreams) then return "memory_of_lucid_dreams"; end
    end
    -- blood_of_the_enemy,if=buff.icicles.stack=5&buff.brain_freeze.react|active_enemies>4
    if S.BloodOfTheEnemy:IsCastableP() and (Player:BuffStackP(S.IciclesBuff) == 5 and Player:BuffP(S.BrainFreezeBuff) or EnemiesCount > 4) then
      if HR.Cast(S.BloodOfTheEnemy) then return "blood_of_the_enemy"; end
    end
    -- purifying_blast
    if S.PurifyingBlast:IsCastableP() then
      if HR.Cast(S.PurifyingBlast) then return "purifying_blast"; end
    end
    -- ripple_in_space
    if S.RippleInSpace:IsCastableP() then
      if HR.Cast(S.RippleInSpace) then return "ripple_in_space"; end
    end
    -- concentrated_flame
    if S.ConcentratedFlame:IsCastableP() then
      if HR.Cast(S.ConcentratedFlame) then return "concentrated_flame"; end
    end
    -- the_unbound_force,if=buff.reckless_force.up
    if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForce)) then
      if HR.Cast(S.TheUnboundForce) then return "the_unbound_force"; end
    end
    -- worldvein_resonance
    if S.WorldveinResonance:IsCastableP() then
      if HR.Cast(S.WorldveinResonance) then return "worldvein_resonance"; end
    end
  end
  Aoe = function()
    -- frozen_orb
    if S.FrozenOrb:IsCastableP() then
      if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb) then return "frozen_orb 16"; end
    end
    -- blizzard
    if S.Blizzard:IsCastableP() then
      if HR.Cast(S.Blizzard) then return "blizzard 18"; end
    end
    -- call_action_list,name=essences
    local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    -- comet_storm
    if S.CometStorm:IsCastableP() then
      if HR.Cast(S.CometStorm) then return "comet_storm 20"; end
    end
    -- ice_nova
    if S.IceNova:IsCastableP() then
      if HR.Cast(S.IceNova) then return "ice_nova 22"; end
    end
    -- flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.frostbolt&(buff.icicles.stack<4|!talent.glacial_spike.enabled)|prev_gcd.1.glacial_spike)
    if S.Flurry:IsCastableP() and (Player:PrevGCDP(1, S.Ebonbolt) or bool(Player:BuffStackP(S.BrainFreezeBuff)) and (Player:PrevGCDP(1, S.Frostbolt) and (Player:BuffStackP(S.IciclesBuff) < 4 or not S.GlacialSpike:IsAvailable()) or Player:PrevGCDP(1, S.GlacialSpike))) then
      if HR.Cast(S.Flurry) then return "flurry 24"; end
    end
    -- ice_lance,if=buff.fingers_of_frost.react
    if S.IceLance:IsCastableP() and (bool(Player:BuffStackP(S.FingersofFrostBuff))) then
      if HR.Cast(S.IceLance) then return "ice_lance 38"; end
    end
    -- ray_of_frost
    if S.RayofFrost:IsCastableP() then
      if HR.Cast(S.RayofFrost) then return "ray_of_frost 42"; end
    end
    -- ebonbolt
    if S.Ebonbolt:IsCastableP() then
      if HR.Cast(S.Ebonbolt) then return "ebonbolt 44"; end
    end
    -- glacial_spike
    if S.GlacialSpike:IsCastableP() then
      if HR.Cast(S.GlacialSpike) then return "glacial_spike 46"; end
    end
    -- cone_of_cold
    if S.ConeofCold:IsCastableP() and (EnemiesCount >= 1) then
      if HR.Cast(S.ConeofCold) then return "cone_of_cold 48"; end
    end
    -- use_item,name=tidestorm_codex,if=buff.icy_veins.down&buff.rune_of_power.down
    if I.TidestormCodex:IsReady() and (Player:BuffDownP(S.IcyVeins) and Player:BuffDownP(S.RuneofPowerBuff)) then
      if HR.Cast(I.TidestormCodex) then return "tidestorm_codex 49"; end
    end
    -- frostbolt
    if S.Frostbolt:IsCastableP() then
      if HR.Cast(S.Frostbolt) then return "frostbolt 50"; end
    end
    -- call_action_list,name=movement
    if (true) then
      local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    end
    -- ice_lance
    if S.IceLance:IsCastableP() then
      if HR.Cast(S.IceLance) then return "ice_lance 54"; end
    end
  end
  Cooldowns = function()
    -- icy_veins
    if S.IcyVeins:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins 56"; end
    end
    -- mirror_image
    if S.MirrorImage:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.MirrorImage, Settings.Frost.GCDasOffGCD.MirrorImage) then return "mirror_image 58"; end
    end
    -- rune_of_power,if=prev_gcd.1.frozen_orb|target.time_to_die>10+cast_time&target.time_to_die<20
    if S.RuneofPower:IsCastableP() and (Player:PrevGCDP(1, S.FrozenOrb) or Target:TimeToDie() > 10 + S.RuneofPower:CastTime() and Target:TimeToDie() < 20) then
      if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return "rune_of_power 60"; end
    end
    -- call_action_list,name=talent_rop,if=talent.rune_of_power.enabled&active_enemies=1&cooldown.rune_of_power.full_recharge_time<cooldown.frozen_orb.remains
    if (S.RuneofPower:IsAvailable() and EnemiesCount == 1 and S.RuneofPower:FullRechargeTimeP() < S.FrozenOrb:CooldownRemainsP()) then
      local ShouldReturn = TalentRop(); if ShouldReturn then return ShouldReturn; end
    end
    -- potion,if=prev_gcd.1.icy_veins|target.time_to_die<30
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (Player:PrevGCDP(1, S.IcyVeins) or Target:TimeToDie() < 30) then
      if HR.CastSuggested(I.ProlongedPower) then return "prolonged_power 96"; end
    end
    -- use_items
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 101"; end
    end
    -- berserking
    if S.Berserking:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 103"; end
    end
    -- lights_judgment
    if S.LightsJudgment:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 105"; end
    end
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 107"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastableP() and HR.CDsON() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 109"; end
    end
  end
  Movement = function()
    -- blink,if=movement.distance>10
    if BlinkAny:IsCastableP() and (not Target:IsInRange(S.Frostbolt:MaximumRange())) then
      if HR.Cast(BlinkAny) then return "blink 111"; end
    end
    -- ice_floes,if=buff.ice_floes.down
    if S.IceFloes:IsCastableP() and (Player:BuffDownP(S.IceFloesBuff)) then
      if HR.Cast(S.IceFloes, Settings.Frost.OffGCDasOffGCD.IceFloes) then return "ice_floes 113"; end
    end
  end
  Single = function()
    -- ice_nova,if=cooldown.ice_nova.ready&debuff.winters_chill.up
    if S.IceNova:IsCastableP() and (S.IceNova:CooldownUpP() and Target:DebuffP(S.WintersChillDebuff)) then
      if HR.Cast(S.IceNova) then return "ice_nova 117"; end
    end
    -- flurry,if=talent.ebonbolt.enabled&prev_gcd.1.ebonbolt&(!talent.glacial_spike.enabled|buff.icicles.stack<4|buff.brain_freeze.react)
    if S.Flurry:IsCastableP() and (S.Ebonbolt:IsAvailable() and Player:PrevGCDP(1, S.Ebonbolt) and (not S.GlacialSpike:IsAvailable() or Player:BuffStackP(S.IciclesBuff) < 4 or bool(Player:BuffStackP(S.BrainFreezeBuff)))) then
      if HR.Cast(S.Flurry) then return "flurry 123"; end
    end
    -- flurry,if=talent.glacial_spike.enabled&prev_gcd.1.glacial_spike&buff.brain_freeze.react
    if S.Flurry:IsCastableP() and (S.GlacialSpike:IsAvailable() and Player:PrevGCDP(1, S.GlacialSpike) and bool(Player:BuffStackP(S.BrainFreezeBuff))) then
      if HR.Cast(S.Flurry) then return "flurry 135"; end
    end
    -- flurry,if=prev_gcd.1.frostbolt&buff.brain_freeze.react&(!talent.glacial_spike.enabled|buff.icicles.stack<4)
    if S.Flurry:IsCastableP() and (Player:PrevGCDP(1, S.Frostbolt) and bool(Player:BuffStackP(S.BrainFreezeBuff)) and (not S.GlacialSpike:IsAvailable() or Player:BuffStackP(S.IciclesBuff) < 4)) then
      if HR.Cast(S.Flurry) then return "flurry 143"; end
    end
    -- call_action_list,name=essences
    local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    -- frozen_orb
    if S.FrozenOrb:IsCastableP() then
      if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb) then return "frozen_orb 153"; end
    end
    -- blizzard,if=active_enemies>2|active_enemies>1&cast_time=0&buff.fingers_of_frost.react<2
    if S.Blizzard:IsCastableP() and (EnemiesCount > 2 or EnemiesCount > 1 and S.Blizzard:CastTime() == 0 and Player:BuffStackP(S.FingersofFrostBuff) < 2) then
      if HR.Cast(S.Blizzard) then return "blizzard 155"; end
    end
    -- ice_lance,if=buff.fingers_of_frost.react
    if S.IceLance:IsCastableP() and (bool(Player:BuffStackP(S.FingersofFrostBuff))) then
      if HR.Cast(S.IceLance) then return "ice_lance 175"; end
    end
    -- comet_storm
    if S.CometStorm:IsCastableP() then
      if HR.Cast(S.CometStorm) then return "comet_storm 179"; end
    end
    -- ebonbolt
    if S.Ebonbolt:IsCastableP() then
      if HR.Cast(S.Ebonbolt) then return "ebonbolt 181"; end
    end
    -- ray_of_frost,if=!action.frozen_orb.in_flight&ground_aoe.frozen_orb.remains=0
    if S.RayofFrost:IsCastableP() and (not S.FrozenOrb:InFlight() and Player:FrozenOrbGroundAoeRemains() == 0) then
      if HR.Cast(S.RayofFrost) then return "ray_of_frost 183"; end
    end
    -- blizzard,if=cast_time=0|active_enemies>1
    if S.Blizzard:IsCastableP() and (S.Blizzard:CastTime() == 0 or EnemiesCount > 1) then
      if HR.Cast(S.Blizzard) then return "blizzard 189"; end
    end
    -- glacial_spike,if=buff.brain_freeze.react|prev_gcd.1.ebonbolt|active_enemies>1&talent.splitting_ice.enabled
    if S.GlacialSpike:IsCastableP() and (bool(Player:BuffStackP(S.BrainFreezeBuff)) or Player:PrevGCDP(1, S.Ebonbolt) or EnemiesCount > 1 and S.SplittingIce:IsAvailable()) then
      if HR.Cast(S.GlacialSpike) then return "glacial_spike 201"; end
    end
    -- ice_nova
    if S.IceNova:IsCastableP() then
      if HR.Cast(S.IceNova) then return "ice_nova 217"; end
    end
    -- use_item,name=tidestorm_codex,if=buff.icy_veins.down&buff.rune_of_power.down
    if I.TidestormCodex:IsReady() and (Player:BuffDownP(S.IcyVeins) and Player:BuffDownP(S.RuneofPowerBuff)) then
      if HR.Cast(I.TidestormCodex) then return "tidestorm_codex 218"; end
    end
    -- frostbolt
    if S.Frostbolt:IsCastableP() then
      if HR.Cast(S.Frostbolt) then return "frostbolt 219"; end
    end
    -- call_action_list,name=movement
    -- if (true) then
    --   local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    -- end
    -- ice_lance
    if S.IceLance:IsCastableP() then
      if HR.Cast(S.IceLance) then return "ice_lance 223"; end
    end
  end
  TalentRop = function()
    -- rune_of_power,if=talent.glacial_spike.enabled&buff.icicles.stack=5&(buff.brain_freeze.react|talent.ebonbolt.enabled&cooldown.ebonbolt.remains<cast_time)
    if S.RuneofPower:IsCastableP() and (S.GlacialSpike:IsAvailable() and Player:BuffStackP(S.IciclesBuff) == 5 and (bool(Player:BuffStackP(S.BrainFreezeBuff)) or S.Ebonbolt:IsAvailable() and S.Ebonbolt:CooldownRemainsP() < S.RuneofPower:CastTime())) then
      if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return "rune_of_power 225"; end
    end
    -- rune_of_power,if=!talent.glacial_spike.enabled&(talent.ebonbolt.enabled&cooldown.ebonbolt.remains<cast_time|talent.comet_storm.enabled&cooldown.comet_storm.remains<cast_time|talent.ray_of_frost.enabled&cooldown.ray_of_frost.remains<cast_time|charges_fractional>1.9)
    if S.RuneofPower:IsCastableP() and (not S.GlacialSpike:IsAvailable() and (S.Ebonbolt:IsAvailable() and S.Ebonbolt:CooldownRemainsP() < S.RuneofPower:CastTime() or S.CometStorm:IsAvailable() and S.CometStorm:CooldownRemainsP() < S.RuneofPower:CastTime() or S.RayofFrost:IsAvailable() and S.RayofFrost:CooldownRemainsP() < S.RuneofPower:CastTime() or S.RuneofPower:ChargesFractionalP() > 1.9)) then
      if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return "rune_of_power 243"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and (not Player:IsCasting() or Player:IsCasting(S.WaterElemental)) then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell
    Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false);
    -- ice_lance,if=prev_gcd.1.flurry&!buff.fingers_of_frost.react
    if S.IceLance:IsCastableP() and (Player:PrevGCDP(1, S.Flurry) and not bool(Player:BuffStackP(S.FingersofFrostBuff))) then
      if HR.Cast(S.IceLance) then return "ice_lance 285"; end
    end
    -- call_action_list,name=cooldowns
    if HR.CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>3&talent.freezing_rain.enabled|active_enemies>4
    if (EnemiesCount > 3 and S.FreezingRain:IsAvailable() or EnemiesCount > 4) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=single
    if (true) then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

HR.SetAPL(64, APL)
