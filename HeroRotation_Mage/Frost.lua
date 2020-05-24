--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation

-- Azerite Essence Setup
local AE         = HL.Enum.AzeriteEssences
local AESpellIDs = HL.Enum.AzeriteEssenceSpellIDs

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
  BagofTricks                           = Spell(312411),
  Blink                                 = MultiSpell(1953, 212653),
  IceFloes                              = Spell(108839),
  IceFloesBuff                          = Spell(108839),
  WintersChillDebuff                    = Spell(228358),
  GlacialSpikeBuff                      = Spell(199844),
  SplittingIce                          = Spell(56377),
  FreezingRain                          = Spell(240555),
  Counterspell                          = Spell(2139),
  IncantersFlow                         = Spell(1463),
  IncantersFlowBuff                     = Spell(116267),
  BloodoftheEnemy                       = Spell(297108),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368)
};
local S = Spell.Mage.Frost;

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Frost = {
  PotionofFocusedResolve           = Item(168506),
  BalefireBranch                   = Item(159630, {13, 14}),
  TidestormCodex                   = Item(165576, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14})
};
local I = Item.Mage.Frost;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.BalefireBranch:ID(),
  I.TidestormCodex:ID(),
  I.PocketsizedComputationDevice:ID()
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount;
local Mage = HR.Commons.Mage

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

HL:RegisterForEvent(function()
  S.FrozenOrb:RegisterInFlight();
end, "LEARNED_SPELL_IN_TAB")
S.FrozenOrb:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

S.FrozenOrb.EffectID = 84721
S.Frostbolt:RegisterInFlight()

local function Precombat()
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
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "potion 12"; end
    end
    -- frostbolt
    if S.Frostbolt:IsCastableP() then
      if HR.Cast(S.Frostbolt, nil, nil, 40) then return "frostbolt 14"; end
    end
  end
end

local function Essences()
  -- focused_azerite_beam,if=buff.rune_of_power.down|active_enemies>3
  if S.FocusedAzeriteBeam:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) or EnemiesCount > 3) then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
  end
  -- memory_of_lucid_dreams,if=active_enemies<5&(buff.icicles.stack<=1|!talent.glacial_spike.enabled)&cooldown.frozen_orb.remains>10
  if S.MemoryofLucidDreams:IsCastableP() and (EnemiesCount < 5 and (Player:BuffStackP(S.IciclesBuff) <= 1 or not S.GlacialSpike:IsAvailable()) and S.FrozenOrb:CooldownRemainsP() > 10) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
  end
  -- blood_of_the_enemy,if=(talent.glacial_spike.enabled&buff.icicles.stack=5&(buff.brain_freeze.react|prev_gcd.1.ebonbolt))|((active_enemies>3|!talent.glacial_spike.enabled)&(prev_gcd.1.frozen_orb|ground_aoe.frozen_orb.remains>5))
  if S.BloodoftheEnemy:IsCastableP() and ((S.GlacialSpike:IsAvailable() and Player:BuffStackP(S.IciclesBuff) == 5 and (Player:BuffP(S.BrainFreezeBuff) or Player:PrevGCDP(1, S.Ebonbolt))) or ((EnemiesCount > 3 or not S.GlacialSpike:IsAvailable()) and (Player:PrevGCDP(1, S.FrozenOrb) or Player:FrozenOrbGroundAoeRemains() > 5))) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, 12) then return "blood_of_the_enemy"; end
  end
  -- purifying_blast,if=buff.rune_of_power.down|active_enemies>3
  if S.PurifyingBlast:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) or EnemiesCount > 3) then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "purifying_blast"; end
  end
  -- ripple_in_space,if=buff.rune_of_power.down|active_enemies>3
  if S.RippleInSpace:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) or EnemiesCount > 3) then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
  end
  -- concentrated_flame,line_cd=6,if=buff.rune_of_power.down
  if S.ConcentratedFlame:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff)) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "concentrated_flame"; end
  end
  -- reaping_flames,if=buff.rune_of_power.down
  if (Player:BuffDownP(S.RuneofPowerBuff)) then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  end
  -- the_unbound_force,if=buff.reckless_force.up
  if S.TheUnboundForce:IsCastableP() and (Player:BuffP(S.RecklessForceBuff)) then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, 40) then return "the_unbound_force"; end
  end
  -- worldvein_resonance,if=buff.rune_of_power.down|active_enemies>3
  if S.WorldveinResonance:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) or EnemiesCount > 3) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
  end
end

local function Aoe()
  -- frozen_orb
  if S.FrozenOrb:IsCastableP() then
    if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, 40) then return "frozen_orb 16"; end
  end
  -- blizzard
  if S.Blizzard:IsCastableP() then
    if HR.Cast(S.Blizzard, nil, nil, 40) then return "blizzard 18"; end
  end
  -- call_action_list,name=essences
  local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
  -- comet_storm
  if S.CometStorm:IsCastableP() then
    if HR.Cast(S.CometStorm, nil, nil, 40) then return "comet_storm 20"; end
  end
  -- ice_nova
  if S.IceNova:IsCastableP() then
    if HR.Cast(S.IceNova, nil, nil, 40) then return "ice_nova 22"; end
  end
  -- flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.frostbolt&(buff.icicles.stack<4|!talent.glacial_spike.enabled)|prev_gcd.1.glacial_spike)
  if S.Flurry:IsCastableP() and (Player:PrevGCDP(1, S.Ebonbolt) or bool(Player:BuffStackP(S.BrainFreezeBuff)) and (Player:PrevGCDP(1, S.Frostbolt) and (Player:BuffStackP(S.IciclesBuff) < 4 or not S.GlacialSpike:IsAvailable()) or Player:PrevGCDP(1, S.GlacialSpike))) then
    if HR.Cast(S.Flurry, nil, nil, 40) then return "flurry 24"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsCastableP() and (bool(Player:BuffStackP(S.FingersofFrostBuff))) then
    if HR.Cast(S.IceLance, nil, nil, 40) then return "ice_lance 38"; end
  end
  -- ray_of_frost
  if S.RayofFrost:IsCastableP() then
    if HR.Cast(S.RayofFrost, nil, nil, 40) then return "ray_of_frost 42"; end
  end
  -- ebonbolt
  if S.Ebonbolt:IsCastableP() then
    if HR.Cast(S.Ebonbolt, nil, nil, 40) then return "ebonbolt 44"; end
  end
  -- glacial_spike
  if S.GlacialSpike:IsCastableP() then
    if HR.Cast(S.GlacialSpike, nil, nil, 40) then return "glacial_spike 46"; end
  end
  -- cone_of_cold
  if S.ConeofCold:IsCastableP() and (EnemiesCount >= 1) then
    if HR.Cast(S.ConeofCold, nil, nil, 12) then return "cone_of_cold 48"; end
  end
  -- use_item,name=tidestorm_codex,if=buff.icy_veins.down&buff.rune_of_power.down
  if I.TidestormCodex:IsEquipReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.IcyVeins) and Player:BuffDownP(S.RuneofPowerBuff)) then
    if HR.Cast(I.TidestormCodex, nil, Settings.Commons.TrinketDisplayStyle, 50) then return "tidestorm_codex 49"; end
  end
  -- use_item,effect_name=cyclotronic_blast,if=buff.icy_veins.down&buff.rune_of_power.down
  if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.IcyVeins) and Player:BuffDownP(S.RuneofPowerBuff)) then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "pocketsized_computation_device aoe"; end
  end
  -- frostbolt
  if S.Frostbolt:IsCastableP() then
    if HR.Cast(S.Frostbolt, nil, nil, 40) then return "frostbolt 50"; end
  end
  -- call_action_list,name=movement
  if (true) then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
  -- ice_lance
  if S.IceLance:IsCastableP() then
    if HR.Cast(S.IceLance, nil, nil, 40) then return "ice_lance 54"; end
  end
end

local function Cooldowns()
  -- guardian_of_azeroth
  if S.GuardianofAzeroth:IsCastableP() then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
  end
  -- icy_veins
  if S.IcyVeins:IsCastableP() then
    if HR.Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins 56"; end
  end
  -- mirror_image
  if S.MirrorImage:IsCastableP() then
    if HR.Cast(S.MirrorImage, Settings.Frost.GCDasOffGCD.MirrorImage) then return "mirror_image 58"; end
  end
  -- rune_of_power,if=buff.rune_of_power.down&(prev_gcd.1.frozen_orb|target.time_to_die>10+cast_time&target.time_to_die<20)
  if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and (Player:PrevGCDP(1, S.FrozenOrb) or Target:TimeToDie() > 10 + S.RuneofPower:CastTime() and Target:TimeToDie() < 20)) then
    if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return "rune_of_power 60"; end
  end
  -- call_action_list,name=talent_rop,if=talent.rune_of_power.enabled&active_enemies=1&cooldown.rune_of_power.full_recharge_time<cooldown.frozen_orb.remains
  if (S.RuneofPower:IsAvailable() and EnemiesCount == 1 and S.RuneofPower:FullRechargeTimeP() < S.FrozenOrb:CooldownRemainsP()) then
    local ShouldReturn = TalentRop(); if ShouldReturn then return ShouldReturn; end
  end
  -- potion,if=prev_gcd.1.icy_veins|target.time_to_die<30
  if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and (Player:PrevGCDP(1, S.IcyVeins) or Target:TimeToDie() < 30) then
    if HR.CastSuggested(I.PotionofFocusedResolve) then return "potion 96"; end
  end
  -- use_item,name=balefire_branch,if=!talent.glacial_spike.enabled|buff.brain_freeze.react&prev_gcd.1.glacial_spike
  if I.BalefireBranch:IsEquipReady() and (not S.GlacialSpike:IsAvailable() or Player:BuffP(S.BrainFreezeBuff) and Player:PrevGCDP(1, S.GlacialSpike)) then
    if HR.Cast(I.BalefireBranch, nil, Settings.Commons.TrinketDisplayStyle) then return "balefire_branch 98"; end
  end
  -- use_items
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
  -- use_item,name=pocketsized_computation_device,if=!cooldown.cyclotronic_blast.duration
  if Everyone.PSCDEquipReady() and Settings.Commons.UseTrinkets then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "pocketsized_computation_device 100"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastableP() then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 101"; end
  end
  -- berserking
  if S.Berserking:IsCastableP() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 103"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastableP() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "lights_judgment 105"; end
  end
  -- fireblood
  if S.Fireblood:IsCastableP() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 107"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastableP() then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 109"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastableP() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, 40) then return "bag_of_tricks 111"; end
  end
end

local function Movement()
  -- blink,if=movement.distance>10
  if S.Blink:IsCastableP() and (not Target:IsInRange(S.Frostbolt:MaximumRange())) then
    if HR.Cast(S.Blink) then return "blink 111"; end
  end
  -- ice_floes,if=buff.ice_floes.down
  if S.IceFloes:IsCastableP() and (Player:BuffDownP(S.IceFloesBuff)) then
    if HR.Cast(S.IceFloes, Settings.Frost.OffGCDasOffGCD.IceFloes) then return "ice_floes 113"; end
  end
end

local function Single()
  -- ice_nova,if=cooldown.ice_nova.ready&debuff.winters_chill.up
  if S.IceNova:IsCastableP() and (S.IceNova:CooldownUpP() and Target:DebuffP(S.WintersChillDebuff)) then
    if HR.Cast(S.IceNova, nil, nil, 40) then return "ice_nova 117"; end
  end
  -- flurry,if=talent.ebonbolt.enabled&prev_gcd.1.ebonbolt&buff.brain_freeze.react
  if S.Flurry:IsCastableP() and (S.Ebonbolt:IsAvailable() and Player:PrevGCDP(1, S.Ebonbolt) and bool(Player:BuffStackP(S.BrainFreezeBuff))) then
    if HR.Cast(S.Flurry, nil, nil, 40) then return "flurry 123"; end
  end
  -- flurry,if=prev_gcd.1.glacial_spike&buff.brain_freeze.react
  if S.Flurry:IsCastableP() and (Player:PrevGCDP(1, S.GlacialSpike) and bool(Player:BuffStackP(S.BrainFreezeBuff))) then
    if HR.Cast(S.Flurry, nil, nil, 40) then return "flurry 135"; end
  end
  -- call_action_list,name=essences
  local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
  -- frozen_orb
  if S.FrozenOrb:IsCastableP() then
    if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, 40) then return "frozen_orb 153"; end
  end
  -- blizzard,if=active_enemies>2|active_enemies>1&!talent.splitting_ice.enabled
  if S.Blizzard:IsCastableP() and (EnemiesCount > 2 or EnemiesCount > 1 and not S.SplittingIce:IsAvailable()) then
    if HR.Cast(S.Blizzard, nil, nil, 40) then return "blizzard 155"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastableP() then
    if HR.Cast(S.CometStorm, nil, nil, 40) then return "comet_storm 179"; end
  end
  -- ebonbolt,if=buff.icicles.stack=5&!buff.brain_freeze.react
  if S.Ebonbolt:IsCastableP() and (Player:BuffStackP(S.IciclesBuff) == 5 and Player:BuffDownP(S.BrainFreezeBuff)) then
    if HR.Cast(S.Ebonbolt, nil, nil, 40) then return "ebonbolt 181"; end
  end
  -- ice_lance,if=buff.brain_freeze.react&(buff.fingers_of_frost.react|prev_gcd.1.flurry)&(buff.icicles.max_stack-buff.icicles.stack)*action.frostbolt.execute_time+action.glacial_spike.cast_time+action.glacial_spike.travel_time<incanters_flow_time_to.5.any&buff.memory_of_lucid_dreams.down
  if S.IceLance:IsCastableP() and (S.GlacialSpike:IsAvailable() and S.IncantersFlow:IsAvailable() and Player:BuffP(S.BrainFreezeBuff) and (Player:BuffP(S.FingersofFrostBuff) or Player:PrevGCDP(1, S.Flurry)) and (5 - Player:BuffStackP(S.IciclesBuff)) * S.Frostbolt:ExecuteTime() + S.GlacialSpike:CastTime() + S.GlacialSpike:TravelTime() < Mage.IFTimeToX(5, "any") and Player:BuffDownP(S.MemoryofLucidDreams)) then
    if HR.Cast(S.IceLance, nil, nil, 40) then return "ice_lance 182"; end
  end
  -- glacial_spike,if=buff.brain_freeze.react|prev_gcd.1.ebonbolt|talent.incanters_flow.enabled&cast_time+travel_time>incanters_flow_time_to.5.up&cast_time+travel_time<incanters_flow_time_to.4.down
  if S.GlacialSpike:IsReadyP() and (Player:BuffP(S.BrainFreezeBuff) or Player:PrevGCDP(1, S.Ebonbolt) or S.IncantersFlow:IsAvailable() and S.GlacialSpike:CastTime() + S.GlacialSpike:TravelTime() > Mage.IFTimeToX(5, "up") and S.GlacialSpike:CastTime() and S.GlacialSpike:TravelTime() < Mage.IFTimeToX(4, "down")) then
    if HR.Cast(S.GlacialSpike, nil, nil, 40) then return "glacial_spike 183"; end
  end
  -- ice_nova
  if S.IceNova:IsCastableP() then
    if HR.Cast(S.IceNova, nil, nil, 40) then return "ice_nova 184"; end
  end
  -- use_item,name=tidestorm_codex,if=buff.icy_veins.down&buff.rune_of_power.down
  if I.TidestormCodex:IsEquipReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.IcyVeins) and Player:BuffDownP(S.RuneofPowerBuff)) then
    if HR.Cast(I.TidestormCodex, nil, Settings.Commons.TrinketDisplayStyle, 50) then return "tidestorm_codex 218"; end
  end
  -- use_item,effect_name=cyclotronic_blast,if=buff.icy_veins.down&buff.rune_of_power.down
  if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (Player:BuffDownP(S.IcyVeins) and Player:BuffDownP(S.RuneofPowerBuff)) then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, 40) then return "pocketsized_computation_device single"; end
  end
  -- Manual addition of Ice Lance with FoF proc if not using Glacial Spike
  if S.IceLance:IsCastableP() and (not S.GlacialSpike:IsAvailable() and Player:BuffP(S.FingersofFrostBuff)) then
    if HR.Cast(S.IceLance, nil, nil, 40) then return "ice_lance 222"; end
  end
  -- frostbolt
  if S.Frostbolt:IsCastableP() then
    if HR.Cast(S.Frostbolt, nil, nil, 40) then return "frostbolt 224"; end
  end
  -- call_action_list,name=movement
  -- if (true) then
  --   local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  -- end
  -- ice_lance
  if S.IceLance:IsCastableP() then
    if HR.Cast(S.IceLance, nil, nil, 40) then return "ice_lance 223"; end
  end
end

local function TalentRop()
  -- rune_of_power,if=buff.rune_of_power.down&talent.glacial_spike.enabled&buff.icicles.stack=5&(buff.brain_freeze.react|talent.ebonbolt.enabled&cooldown.ebonbolt.remains<cast_time)
  if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and S.GlacialSpike:IsAvailable() and Player:BuffStackP(S.IciclesBuff) == 5 and (bool(Player:BuffStackP(S.BrainFreezeBuff)) or S.Ebonbolt:IsAvailable() and S.Ebonbolt:CooldownRemainsP() < S.RuneofPower:CastTime())) then
    if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return "rune_of_power 225"; end
  end
  -- rune_of_power,if=buff.rune_of_power.down&!talent.glacial_spike.enabled&(talent.ebonbolt.enabled&cooldown.ebonbolt.remains<cast_time|talent.comet_storm.enabled&cooldown.comet_storm.remains<cast_time|talent.ray_of_frost.enabled&cooldown.ray_of_frost.remains<cast_time|charges_fractional>1.9)
  if S.RuneofPower:IsCastableP() and (Player:BuffDownP(S.RuneofPowerBuff) and not S.GlacialSpike:IsAvailable() and (S.Ebonbolt:IsAvailable() and S.Ebonbolt:CooldownRemainsP() < S.RuneofPower:CastTime() or S.CometStorm:IsAvailable() and S.CometStorm:CooldownRemainsP() < S.RuneofPower:CastTime() or S.RayofFrost:IsAvailable() and S.RayofFrost:CooldownRemainsP() < S.RuneofPower:CastTime() or S.RuneofPower:ChargesFractionalP() > 1.9)) then
    if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return "rune_of_power 243"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesCount = GetEnemiesCount(8)
  Mage.IFTracker()

  -- call precombat
  if not Player:AffectingCombat() and (not Player:IsCasting() or Player:IsCasting(S.WaterElemental)) then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell
    Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false);
    -- call_action_list,name=cooldowns
    if (HR.CDsON()) then
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

local function Init()
  HL.RegisterNucleusAbility(84714, 8, 6)               -- Frost Orb
  HL.RegisterNucleusAbility(190356, 8, 6)              -- Blizzard
  HL.RegisterNucleusAbility(153595, 8, 6)              -- Comet Storm
  HL.RegisterNucleusAbility(120, 12, 6)                -- Cone of Cold
end

HR.SetAPL(64, APL, Init)
