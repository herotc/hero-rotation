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
  -- Racials
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Base Abilities
  ArcaneExplosion                       = Spell(1449),
  ArcaneIntellect                       = Spell(1459),
  ArcaneIntellectBuff                   = Spell(1459),
  Blink                                 = MultiSpell(1953, 212653),
  Blizzard                              = Spell(190356),
  BrainFreezeBuff                       = Spell(190446),
  ConeofCold                            = Spell(120),
  Counterspell                          = Spell(2139),
  FingersofFrostBuff                    = Spell(44544),
  Flurry                                = Spell(44614),
  Frostbolt                             = Spell(116),
  FrozenOrb                             = Spell(84714),
  IceLance                              = Spell(30455),
  IciclesBuff                           = Spell(205473),
  IcyVeins                              = Spell(12472),
  MirrorImage                           = Spell(55342),
  SummonWaterElemental                  = Spell(31687),
  WintersChillDebuff                    = Spell(228358),
  -- Talents
  CometStorm                            = Spell(153595),
  Ebonbolt                              = Spell(257537),
  FocusMagic                            = Spell(321358),
  FocusMagicBuff                        = Spell(321363),
  FreezingRain                          = Spell(270233),
  GlacialSpike                          = Spell(199786),
  GlacialSpikeBuff                      = Spell(199844),
  IceFloes                              = Spell(108839),
  IceFloesBuff                          = Spell(108839),
  IceNova                               = Spell(157997),
  IncantersFlow                         = Spell(1463),
  IncantersFlowBuff                     = Spell(116267),
  RayofFrost                            = Spell(205021),
  RuneofPower                           = Spell(116011),
  RuneofPowerBuff                       = Spell(116014),
  SplittingIce                          = Spell(56377),
  -- Covenant Abilities
  Deathborne                            = Spell(324220),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  MirrorsofTorment                      = Spell(314793),
  RadiantSpark                          = Spell(307443),
  RadiantSparkDebuff                    = Spell(307443),
  RaidantSparkVulnerability             = Spell(307454),
  ShiftingPower                         = Spell(314791),
  Soulshape                             = Spell(310143),
  -- Conduit Effects
  -- Azerite Traits
  PackedIceDebuff                       = Spell(272970),
  -- Essences
  BloodoftheEnemy                       = Spell(297108),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  RippleInSpace                         = Spell(302731),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
}
local S = Spell.Mage.Frost

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Frost = {
  PotionofFocusedResolve           = Item(168506),
  BalefireBranch                   = Item(159630, {13, 14}),
  TidestormCodex                   = Item(165576, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14})
}
local I = Item.Mage.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.BalefireBranch:ID(),
  I.TidestormCodex:ID(),
  I.PocketsizedComputationDevice:ID()
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local EnemiesCount
local ILIFGaming
local Mage = HR.Commons.Mage

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Frost = HR.GUISettings.APL.Mage.Frost
}

S.FrozenOrb:RegisterInFlightEffect(84721)
HL:RegisterForEvent(function() S.FrozenOrb:RegisterInFlight() end, "LEARNED_SPELL_IN_TAB")
S.FrozenOrb:RegisterInFlight()
S.Frostbolt:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local EnemyRanges = {40, 12, 8}
local function CacheEnemies()
  for _, i in ipairs(EnemyRanges) do
    Cache.Enemies[i] = Player:GetEnemiesInRange(i)
    Cache.EnemiesCount[i] = #Cache.Enemies[i]
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellectBuff, true) then
    if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect 3"; end
  end
  -- variable,name=incanters_flow_gaming,default=1,op=reset
  ILIFGaming = 0
  -- summon_water_elemental
  if S.SummonWaterElemental:IsCastable() then
    if HR.Cast(S.SummonWaterElemental) then return "summon_water_elemental 7"; end
  end
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- use_item,name=azsharas_font_of_power
    -- mirror_image
    if S.MirrorImage:IsCastable() and HR.CDsON() then
      if HR.Cast(S.MirrorImage, Settings.Frost.GCDasOffGCD.MirrorImage) then return "mirror_image 10"; end
    end
    -- potion
    if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "potion 12"; end
    end
    -- frostbolt
    if S.Frostbolt:IsCastable() then
      if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt 14"; end
    end
  end
end

local function Essences()
  if (Settings.Frost.RotationType == "Standard" or Settings.Frost.RotationType == "No Ice Lance") then
    -- focused_azerite_beam,if=buff.rune_of_power.down|active_enemies>3
    if S.FocusedAzeriteBeam:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or EnemiesCount > 3) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam standard/nil rot 1"; end
    end
    -- memory_of_lucid_dreams,if=active_enemies<5&(buff.icicles.stack<=1|!talent.glacial_spike.enabled)&cooldown.frozen_orb.remains>10
    if S.MemoryofLucidDreams:IsCastable() and (EnemiesCount < 5 and (Player:BuffStack(S.IciclesBuff) <= 1 or not S.GlacialSpike:IsAvailable()) and S.FrozenOrb:CooldownRemains() > 10) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams standard/nil rot 3"; end
    end
    -- blood_of_the_enemy,if=(talent.glacial_spike.enabled&buff.icicles.stack=5&(buff.brain_freeze.react|prev_gcd.1.ebonbolt))|((active_enemies>3|!talent.glacial_spike.enabled)&(prev_gcd.1.frozen_orb|ground_aoe.frozen_orb.remains>5))
    if S.BloodoftheEnemy:IsCastable() and ((S.GlacialSpike:IsAvailable() and Player:BuffStack(S.IciclesBuff) == 5 and (Player:BuffUp(S.BrainFreezeBuff) or Player:PrevGCDP(1, S.Ebonbolt))) or ((EnemiesCount > 3 or not S.GlacialSpike:IsAvailable()) and (Player:PrevGCDP(1, S.FrozenOrb) or Player:FrozenOrbGroundAoeRemains() > 5))) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.BloodoftheEnemy)) then return "blood_of_the_enemy standard/nil rot 5"; end
    end
    -- purifying_blast,if=buff.rune_of_power.down|active_enemies>3
    if S.PurifyingBlast:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or EnemiesCount > 3) then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.PurifyingBlast)) then return "purifying_blast standard/nil rot 7"; end
    end
    -- ripple_in_space,if=buff.rune_of_power.down|active_enemies>3
    if S.RippleInSpace:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or EnemiesCount > 3) then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space standard/nil rot 9"; end
    end
    -- concentrated_flame,line_cd=6,if=buff.rune_of_power.down
    if S.ConcentratedFlame:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff)) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.ConcentratedFlame)) then return "concentrated_flame standard/nil rot 11"; end
    end
    -- reaping_flames,if=buff.rune_of_power.down
    if (Player:BuffDown(S.RuneofPowerBuff)) then
      local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
    end
    -- the_unbound_force,if=buff.reckless_force.up
    if S.TheUnboundForce:IsCastable() and (Player:BuffUp(S.RecklessForceBuff)) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.TheUnboundForce)) then return "the_unbound_force standard/nil rot 13"; end
    end
    -- worldvein_resonance,if=buff.rune_of_power.down|active_enemies>3
    if S.WorldveinResonance:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or EnemiesCount > 3) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance standard/nil rot 15"; end
    end
  end
  if (Settings.Frost.RotationType == "Frozen Orb") then
    -- focused_azerite_beam,if=buff.rune_of_power.down&debuff.packed_ice.down|active_enemies>3
    if S.FocusedAzeriteBeam:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.PackedIceDebuff) or EnemiesCount > 3) then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam fo 1"; end
    end
    -- memory_of_lucid_dreams,if=active_enemies<5&debuff.packed_ice.down&cooldown.frozen_orb.remains>5&!action.frozen_orb.in_flight&ground_aoe.frozen_orb.remains=0
    if S.MemoryofLucidDreams:IsCastable() and (EnemiesCount < 5 and Target:DebuffDown(S.PackedIceDebuff) and S.FrozenOrb:CooldownRemains() > 5 and not S.FrozenOrb:InFlight() and Player:FrozenOrbGroundAoeRemains() == 0) then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams fo 3"; end
    end
    -- blood_of_the_enemy,if=prev_gcd.1.frozen_orb|ground_aoe.frozen_orb.remains>5
    if S.BloodoftheEnemy:IsCastable() and (Player:PrevGCDP(1, S.FrozenOrb) or Player:FrozenOrbGroundAoeRemains() > 5) then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.BloodoftheEnemy)) then return "blood_of_the_enemy fo 5"; end
    end
    -- purifying_blast,if=buff.rune_of_power.down&debuff.packed_ice.down|active_enemies>3
    if S.PurifyingBlast:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.PackedIceDebuff) or EnemiesCount > 3) then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.PurifyingBlast)) then return "purifying_blast fo 7"; end
    end
    -- ripple_in_space,if=buff.rune_of_power.down&debuff.packed_ice.down|active_enemies>3
    if S.RippleInSpace:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.PackedIceDebuff) or EnemiesCount > 3) then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space fo 9"; end
    end
    -- concentrated_flame,line_cd=6,if=buff.rune_of_power.down&debuff.packed_ice.down
    if S.ConcentratedFlame:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.PackedIceDebuff)) then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.ConcentratedFlame)) then return "concentrated_flame fo 11"; end
    end
    -- reaping_flames,if=buff.rune_of_power.down&debuff.packed_ice.down
    if (Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.PackedIceDebuff)) then
      local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
    end
    -- the_unbound_force,if=buff.reckless_force.up
    if S.TheUnboundForce:IsCastable() and (Player:BuffUp(S.RecklessForceBuff)) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.TheUnboundForce)) then return "the_unbound_force fo 13"; end
    end
    -- worldvein_resonance,if=buff.rune_of_power.down&debuff.packed_ice.down&cooldown.frozen_orb.remains<4|active_enemies>3
    if S.WorldveinResonance:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.PackedIceDebuff) and S.FrozenOrb:CooldownRemains() < 4 or EnemiesCount > 3) then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance fo 15"; end
    end
  end
end

local function Aoe()
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsSpellInRange(S.FrozenOrb)) then return "frozen_orb 16"; end
  end
  -- blizzard
  if S.Blizzard:IsCastable() then
    if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard 18"; end
  end
  -- call_action_list,name=essences
  local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
  -- comet_storm
  if S.CometStorm:IsCastable() then
    if HR.Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm 20"; end
  end
  -- ice_nova
  if S.IceNova:IsCastable() then
    if HR.Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova 22"; end
  end
  -- flurry,if=prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.frostbolt&(buff.icicles.stack<4|!talent.glacial_spike.enabled)|prev_gcd.1.glacial_spike)
  if S.Flurry:IsCastable() and (Player:PrevGCDP(1, S.Ebonbolt) or Player:BuffUp(S.BrainFreezeBuff) and (Player:PrevGCDP(1, S.Frostbolt) and (Player:BuffStack(S.IciclesBuff) < 4 or not S.GlacialSpike:IsAvailable()) or Player:PrevGCDP(1, S.GlacialSpike))) then
    if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry 24"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsCastable() and (Player:BuffUp(S.FingersofFrostBuff) or Target:DebuffUp(S.WintersChillDebuff)) then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance 38"; end
  end
  -- ray_of_frost
  if S.RayofFrost:IsCastable() then
    if HR.Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost 42"; end
  end
  -- ebonbolt
  if S.Ebonbolt:IsCastable() then
    if HR.Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt 44"; end
  end
  -- glacial_spike
  if S.GlacialSpike:IsCastable() then
    if HR.Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike 46"; end
  end
  -- cone_of_cold
  if S.ConeofCold:IsCastable() and (Cache.EnemiesCount[12] >= 1) then
    if HR.Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold 48"; end
  end
  -- use_item,name=tidestorm_codex,if=buff.icy_veins.down&buff.rune_of_power.down
  if I.TidestormCodex:IsEquipped() and I.TidestormCodex:IsReady() and Settings.Commons.UseTrinkets and (Player:BuffDown(S.IcyVeins) and Player:BuffDown(S.RuneofPowerBuff)) then
    if HR.Cast(I.TidestormCodex, nil, Settings.Commons.TrinketDisplayStyle, not Target:IsInRange(50)) then return "tidestorm_codex 49"; end
  end
  -- use_item,effect_name=cyclotronic_blast,if=buff.icy_veins.down&buff.rune_of_power.down
  if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (Player:BuffDown(S.IcyVeins) and Player:BuffDown(S.RuneofPowerBuff)) then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, not Target:IsInRange(40)) then return "pocketsized_computation_device aoe"; end
  end
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt 50"; end
  end
  -- call_action_list,name=movement
  if (true) then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
  -- ice_lance
  if S.IceLance:IsCastable() then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance 54"; end
  end
end

local function Cooldowns()
  -- guardian_of_azeroth
  if S.GuardianofAzeroth:IsCastable() then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
  end
  -- icy_veins
  if S.IcyVeins:IsCastable() then
    if HR.Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins 56"; end
  end
  -- mirror_image
  if S.MirrorImage:IsCastable() then
    if HR.Cast(S.MirrorImage, Settings.Frost.GCDasOffGCD.MirrorImage) then return "mirror_image 58"; end
  end
  -- rune_of_power,if=buff.rune_of_power.down&(prev_gcd.1.frozen_orb|target.time_to_die>10+cast_time&target.time_to_die<20)
  if S.RuneofPower:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and (Player:PrevGCDP(1, S.FrozenOrb) or Target:TimeToDie() > 10 + S.RuneofPower:CastTime() and Target:TimeToDie() < 20)) then
    if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return "rune_of_power 60"; end
  end
  -- call_action_list,name=talent_rop,if=talent.rune_of_power.enabled&active_enemies=1&cooldown.rune_of_power.full_recharge_time<cooldown.frozen_orb.remains
  if (S.RuneofPower:IsAvailable() and EnemiesCount == 1 and S.RuneofPower:FullRechargeTime() < S.FrozenOrb:CooldownRemains()) then
    local ShouldReturn = TalentRop(); if ShouldReturn then return ShouldReturn; end
  end
  -- potion,if=prev_gcd.1.icy_veins|target.time_to_die<30
  if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and (Player:PrevGCDP(1, S.IcyVeins) or Target:TimeToDie() < 30) then
    if HR.CastSuggested(I.PotionofFocusedResolve) then return "potion 96"; end
  end
  -- use_item,name=balefire_branch,if=!talent.glacial_spike.enabled|buff.brain_freeze.react&prev_gcd.1.glacial_spike
  if I.BalefireBranch:IsEquipped() and I.BalefireBranch:IsReady() and (not S.GlacialSpike:IsAvailable() or Player:BuffUp(S.BrainFreezeBuff) and Player:PrevGCDP(1, S.GlacialSpike)) then
    if HR.Cast(I.BalefireBranch, nil, Settings.Commons.TrinketDisplayStyle) then return "balefire_branch 98"; end
  end
  -- use_items
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
  -- use_item,name=pocketsized_computation_device,if=!cooldown.cyclotronic_blast.duration
  if Everyone.PSCDEquipReady() and Settings.Commons.UseTrinkets then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, not Target:IsInRange(40)) then return "pocketsized_computation_device 100"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 101"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 103"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment 105"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 107"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 109"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks 111"; end
  end
end

local function Movement()
  -- blink,if=movement.distance>10
  if S.Blink:IsCastable() and (not Target:IsSpellInRange(S.Frostbolt)) then
    if HR.Cast(S.Blink) then return "blink 111"; end
  end
  -- ice_floes,if=buff.ice_floes.down
  if S.IceFloes:IsCastable() and (Player:BuffDown(S.IceFloesBuff)) then
    if HR.Cast(S.IceFloes, Settings.Frost.OffGCDasOffGCD.IceFloes) then return "ice_floes 113"; end
  end
end

local function Single()
  -- ice_nova,if=cooldown.ice_nova.ready&debuff.winters_chill.up
  if S.IceNova:IsCastable() and (S.IceNova:CooldownUp() and Target:DebuffUp(S.WintersChillDebuff)) then
    if HR.Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova 117"; end
  end
  if (Settings.Frost.RotationType == "Standard") then
    -- flurry,if=talent.ebonbolt.enabled&prev_gcd.1.ebonbolt&(!talent.glacial_spike.enabled|buff.icicles.stack<4|buff.brain_freeze.react)
    if S.Flurry:IsCastable() and (S.Ebonbolt:IsAvailable() and Player:PrevGCDP(1, S.Ebonbolt) and (not S.GlacialSpike:IsAvailable() or Player:BuffStack(S.IciclesBuff) < 4 or Player:BuffUp(S.BrainFreezeBuff))) then
      if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single standard 1"; end
    end
    -- flurry,if=talent.glacial_spike.enabled&prev_gcd.1.glacial_spike&buff.brain_freeze.react
    if S.Flurry:IsCastable() and (S.GlacialSpike:IsAvailable() and Player:PrevGCDP(1, S.GlacialSpike) and Player:BuffUp(S.BrainFreezeBuff)) then
      if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single standard 3"; end
    end
    -- flurry,if=prev_gcd.1.frostbolt&buff.brain_freeze.react&(!talent.glacial_spike.enabled|buff.icicles.stack<4)
    if S.Flurry:IsCastable() and (Player:PrevGCDP(1, S.Frostbolt) and Player:BuffUp(S.BrainFreezeBuff) and (not S.GlacialSpike:IsAvailable() or Player:BuffStack(S.IciclesBuff) < 4)) then
      if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single standard 5"; end
    end
    -- call_action_list,name=essences
    local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    -- frozen_orb
    if S.FrozenOrb:IsCastable() then
      if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb single standard 7"; end
    end
    -- blizzard,if=active_enemies>2|active_enemies>1&cast_time=0&buff.fingers_of_frost.react<2
    if S.Blizzard:IsCastable() and (EnemiesCount > 2 or EnemiesCount > 1 and S.Blizzard:CastTime() == 0 and Player:BuffStack(S.FingersofFrostBuff) < 2) then
      if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single standard 9"; end
    end
    -- ice_lance,if=buff.fingers_of_frost.react
    if S.IceLance:IsCastable() and (Player:BuffUp(S.FingersofFrostBuff) or Target:DebuffUp(S.WintersChillDebuff)) then
      if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single standard 11"; end
    end
    -- comet_storm
    if S.CometStorm:IsCastable() then
      if HR.Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single standard 13"; end
    end
    -- ebonbolt
    if S.Ebonbolt:IsCastable() then
      if HR.Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt single standard 15"; end
    end
    -- ray_of_frost,if=!action.frozen_orb.in_flight&ground_aoe.frozen_orb.remains=0
    if S.RayofFrost:IsCastable() and (not S.FrozenOrb:InFlight() and Player:FrozenOrbGroundAoeRemains() == 0) then
      if HR.Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single standard 17"; end
    end
    -- blizzard,if=cast_time=0|active_enemies>1
    if S.Blizzard:IsCastable() and (S.Blizzard:CastTime() == 0 or EnemiesCount > 1) then
      if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single standard 19"; end
    end
    -- glacial_spike,if=buff.brain_freeze.react|prev_gcd.1.ebonbolt|active_enemies>1&talent.splitting_ice.enabled
    if S.GlacialSpike:IsReady() and (Player:BuffUp(S.BrainFreezeBuff) or Player:PrevGCDP(1, S.Ebonbolt) or EnemiesCount > 1 and S.SplittingIce:IsAvailable()) then
      if HR.Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single standard 21"; end
    end
  end
  if (Settings.Frost.RotationType == "No Ice Lance") then
    -- flurry,if=talent.ebonbolt.enabled&prev_gcd.1.ebonbolt&buff.brain_freeze.react
    if S.Flurry:IsCastable() and (S.Ebonbolt:IsAvailable() and Player:PrevGCDP(1, S.Ebonbolt) and bool(Player:BuffStack(S.BrainFreezeBuff))) then
      if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single nil 1"; end
    end
    -- flurry,if=prev_gcd.1.glacial_spike&buff.brain_freeze.react
    if S.Flurry:IsCastable() and (Player:PrevGCDP(1, S.GlacialSpike) and Player:BuffUp(S.BrainFreezeBuff)) then
      if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single nil 3"; end
    end
    -- call_action_list,name=essences
    local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    -- frozen_orb
    if S.FrozenOrb:IsCastable() then
      if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb single nil 5"; end
    end
    -- blizzard,if=active_enemies>2|active_enemies>1&!talent.splitting_ice.enabled
    if S.Blizzard:IsCastable() and (EnemiesCount > 2 or EnemiesCount > 1 and not S.SplittingIce:IsAvailable()) then
      if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single nil 7"; end
    end
    -- comet_storm
    if S.CometStorm:IsCastable() then
      if HR.Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single nil 9"; end
    end
    -- ebonbolt,if=buff.icicles.stack=5&!buff.brain_freeze.react
    if S.Ebonbolt:IsCastable() and (Player:BuffStack(S.IciclesBuff) == 5 and Player:BuffDown(S.BrainFreezeBuff)) then
      if HR.Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt single nil 11"; end
    end
    -- ice_lance,if=variable.incanters_flow_gaming&buff.brain_freeze.react&(buff.fingers_of_frost.react|prev_gcd.1.flurry)&(buff.icicles.max_stack-buff.icicles.stack)*action.frostbolt.execute_time+action.glacial_spike.cast_time+action.glacial_spike.travel_time<incanters_flow_time_to.5.any&buff.memory_of_lucid_dreams.down
    if S.IceLance:IsCastable() and (bool(ILIFGaming) and S.GlacialSpike:IsAvailable() and S.IncantersFlow:IsAvailable() and Player:BuffUp(S.BrainFreezeBuff) and (Player:BuffUp(S.FingersofFrostBuff) or Player:PrevGCDP(1, S.Flurry)) and (5 - Player:BuffStack(S.IciclesBuff)) * S.Frostbolt:ExecuteTime() + S.GlacialSpike:CastTime() + S.GlacialSpike:TravelTime() < Mage.IFTimeToX(5, "any") and Player:BuffDown(S.MemoryofLucidDreams)) then
      if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single nil 13"; end
    end
    -- glacial_spike,if=buff.brain_freeze.react|prev_gcd.1.ebonbolt|talent.incanters_flow.enabled&cast_time+travel_time>incanters_flow_time_to.5.up&cast_time+travel_time<incanters_flow_time_to.4.down
    if S.GlacialSpike:IsReady() and (Player:BuffUp(S.BrainFreezeBuff) or Player:PrevGCDP(1, S.Ebonbolt) or S.IncantersFlow:IsAvailable() and S.GlacialSpike:CastTime() + S.GlacialSpike:TravelTime() > Mage.IFTimeToX(5, "up") and S.GlacialSpike:CastTime() and S.GlacialSpike:TravelTime() < Mage.IFTimeToX(4, "down")) then
      if HR.Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single nil 15"; end
    end
  end
  if (Settings.Frost.RotationType == "Frozen Orb") then
    -- call_action_list,name=essences
    local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    -- frozen_orb
    if S.FrozenOrb:IsCastable() then
      if HR.Cast(S.FrozenOrb, nil, nil, not Target:IsInRange(40)) then return "frozen_orb single fo 1"; end
    end
    -- flurry,if=prev_gcd.1.ebonbolt&buff.brain_freeze.react
    if S.Flurry:IsCastable() and (Player:PrevGCDP(1, S.Ebonbolt) and Player:BuffUp(S.BrainFreezeBuff)) then
      if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single fo 3"; end
    end
    -- blizzard,if=active_enemies>2|active_enemies>1&cast_time=0
    if S.Blizzard:IsCastable() and (EnemiesCount > 2 or EnemiesCount > 1 and S.Blizzard:CastTime() == 0) then
      if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single fo 5"; end
    end
    -- ice_lance,if=buff.fingers_of_frost.react&cooldown.frozen_orb.remains>5|buff.fingers_of_frost.react=2
    if S.IceLance:IsCastable() and ((Player:BuffUp(S.FingersofFrostBuff) or Target:DebuffUp(S.WintersChillDebuff)) and S.FrozenOrb:CooldownRemainsP() > 5 or Player:BuffStack(S.FingersofFrostBuff) == 2) then
      if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single fo 7"; end
    end
    -- blizzard,if=cast_time=0
    if S.Blizzard:IsCastable() and (S.Blizzard:CastTime() == 0) then
      if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single fo 9"; end
    end
    -- flurry,if=prev_gcd.1.ebonbolt
    if S.Flurry:IsCastable() and (Player:PrevGCDP(1, S.Ebonbolt)) then
      if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single fo 11"; end
    end
    -- flurry,if=buff.brain_freeze.react&(prev_gcd.1.frostbolt|debuff.packed_ice.remains>execute_time+action.ice_lance.travel_time)
    if S.Flurry:IsCastable() and (Player:BuffUp(S.BrainFreezeBuff) and (Player:PrevGCDP(1, S.Frostbolt) or Target:DebuffRemains(S.PackedIceDebuff) > S.Flurry:ExecuteTime() + S.IceLance:TravelTime())) then
      if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single fo 13"; end
    end
    -- comet_storm
    if S.CometStorm:IsCastable() then
      if HR.Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single fo 15"; end
    end
    -- ebonbolt
    if S.Ebonbolt:IsCastable() then
      if HR.Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt single fo 17"; end
    end
    -- ray_of_frost,if=debuff.packed_ice.up,interrupt_if=buff.fingers_of_frost.react=2,interrupt_immediate=1"
    if S.RayofFrost:IsCastable() and (Target:DebuffUp(S.PackedIceDebuff)) then
      if HR.Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single fo 19"; end
    end
    -- blizzard
    if S.Blizzard:IsCastable() then
      if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single fo 21"; end
    end
  end
  -- ice_nova
  if S.IceNova:IsCastable() then
    if HR.Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova 184"; end
  end
  -- use_item,name=tidestorm_codex,if=buff.icy_veins.down&buff.rune_of_power.down
  if I.TidestormCodex:IsEquipped() and I.TidestormCodex:IsReady() and Settings.Commons.UseTrinkets and (Player:BuffDown(S.IcyVeins) and Player:BuffDown(S.RuneofPowerBuff)) then
    if HR.Cast(I.TidestormCodex, nil, Settings.Commons.TrinketDisplayStyle, not Target:IsInRange(50)) then return "tidestorm_codex 218"; end
  end
  -- use_item,effect_name=cyclotronic_blast,if=buff.icy_veins.down&buff.rune_of_power.down
  if Everyone.CyclotronicBlastReady() and Settings.Commons.UseTrinkets and (Player:BuffDown(S.IcyVeins) and Player:BuffDown(S.RuneofPowerBuff)) then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, not Target:IsInRange(40)) then return "pocketsized_computation_device single"; end
  end
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt 224"; end
  end
  -- call_action_list,name=movement
  -- if (true) then
  --   local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  -- end
  -- ice_lance
  if S.IceLance:IsCastable() then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance 223"; end
  end
end

local function TalentRop()
  -- rune_of_power,if=buff.rune_of_power.down&talent.glacial_spike.enabled&buff.icicles.stack=5&(buff.brain_freeze.react|talent.ebonbolt.enabled&cooldown.ebonbolt.remains<cast_time)
  if S.RuneofPower:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and S.GlacialSpike:IsAvailable() and Player:BuffStack(S.IciclesBuff) == 5 and (Player:BuffUp(S.BrainFreezeBuff) or S.Ebonbolt:IsAvailable() and S.Ebonbolt:CooldownRemains() < S.RuneofPower:CastTime())) then
    if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return "rune_of_power 225"; end
  end
  -- rune_of_power,if=buff.rune_of_power.down&!talent.glacial_spike.enabled&(talent.ebonbolt.enabled&cooldown.ebonbolt.remains<cast_time|talent.comet_storm.enabled&cooldown.comet_storm.remains<cast_time|talent.ray_of_frost.enabled&cooldown.ray_of_frost.remains<cast_time|charges_fractional>1.9)
  if S.RuneofPower:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and not S.GlacialSpike:IsAvailable() and (S.Ebonbolt:IsAvailable() and S.Ebonbolt:CooldownRemains() < S.RuneofPower:CastTime() or S.CometStorm:IsAvailable() and S.CometStorm:CooldownRemains() < S.RuneofPower:CastTime() or S.RayofFrost:IsAvailable() and S.RayofFrost:CooldownRemains() < S.RuneofPower:CastTime() or S.RuneofPower:ChargesFractional() > 1.9)) then
    if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneofPower) then return "rune_of_power 243"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesCount = Target:GetEnemiesInSplashRangeCount(8)
  Mage.IFTracker()

  -- call precombat
  if not Player:AffectingCombat() and (not Player:IsCasting() or Player:IsCasting(S.WaterElemental)) then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    if (Settings.Frost.RotationType ~= "No Ice Lance") then
      -- ice_lance,if=prev_gcd.1.flurry&!buff.fingers_of_frost.react
      if S.IceLance:IsCastable() and (Player:PrevGCDP(1, S.Flurry) and Player:BuffDown(S.FingersofFrostBuff)) then
        if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance apl standard/fo rot 1"; end
      end
    end
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

end

HR.SetAPL(64, APL, Init)
