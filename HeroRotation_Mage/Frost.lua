--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
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
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Frost
local I = Item.Mage.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.BalefireBranch:ID(),
  I.TidestormCodex:ID(),
  I.PocketsizedComputationDevice:ID()
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local EnemiesCount6ySplash, EnemiesCount8ySplash, EnemiesCount16ySplash, EnemiesCount30ySplash --Enemies arround target
local EnemiesCount10yMelee, EnemiesCount12yMelee, EnemiesCount18yMelee  --Enemies arround player
local Mage = HR.Commons.Mage

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Frost = HR.GUISettings.APL.Mage.Frost
}

S.FrozenOrb:RegisterInFlightEffect(84721)
S.FrozenOrb:RegisterInFlight()
HL:RegisterForEvent(function() S.FrozenOrb:RegisterInFlight() end, "LEARNED_SPELL_IN_TAB")
S.Frostbolt:RegisterInFlightEffect(228597)--also register hitting spell to track in flight (spell book id ~= hitting id)
S.Frostbolt:RegisterInFlight()
S.Flurry:RegisterInFlightEffect(228354)
S.Flurry:RegisterInFlight()
S.IceLance:RegisterInFlightEffect(228598)
S.IceLance:RegisterInFlight()

-- TODO : manage frozen targets
-- spells : FrostNova, Frostbite, Freeze, WintersChillDebuff

local function Precombat ()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellect, true) then
    if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect precombat 1"; end
  end
  -- summon_water_elemental
  if S.SummonWaterElemental:IsCastable() then
    if HR.Cast(S.SummonWaterElemental) then return "summon_water_elemental precombat 2"; end
  end
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- mirror_image
    if S.MirrorImage:IsCastable() and HR.CDsON() then
      if HR.Cast(S.MirrorImage, Settings.Frost.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 3"; end
    end
    -- potion
    --[[ if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "potion precombat 4"; end
    end ]]
    -- frostbolt
    if S.Frostbolt:IsCastable() and not Player:IsCasting(S.Frostbolt) then
      if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt precombat 5"; end
    end
    --frozen_orb
    if S.FrozenOrb:IsCastable() then
      if HR.Cast(S.FrozenOrb, nil, nil, not Target:IsInRange(40)) then return "frozen_orb precombat 6"; end
    end
  end
end

local function Essences ()
  --guardian_of_azeroth - Essence
  if S.GuardianofAzeroth:IsCastable() then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth essences 1"; end
  end
  --focused_azerite_beam,if=buff.rune_of_power.down|active_enemies>3
  if S.FocusedAzeriteBeam:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or EnemiesCount30ySplash > 3) then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam essences 2"; end
  end
  --memory_of_lucid_dreams,if=active_enemies<5&(buff.icicles.stack<=1|!talent.glacial_spike.enabled)&cooldown.frozen_orb.remains>10
  if S.MemoryofLucidDreams:IsCastable() and (EnemiesCount8ySplash < 5 and (Player:BuffStack(S.IciclesBuff) <= 1 or not S.GlacialSpike:IsAvailable()) and S.FrozenOrb:CooldownRemains() > 10) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams essences 3"; end
  end
  --blood_of_the_enemy,if=(talent.glacial_spike.enabled&buff.icicles.stack=5&(buff.brain_freeze.react|prev_gcd.1.ebonbolt))|((active_enemies>3|!talent.glacial_spike.enabled)&(prev_gcd.1.frozen_orb|ground_aoe.frozen_orb.remains>5))
  if S.BloodoftheEnemy:IsCastable() and ((S.GlacialSpike:IsAvailable() and Player:BuffStack(S.IciclesBuff) == 5 and (Player:BuffUp(S.BrainFreezeBuff) or Player:IsCasting(S.Ebonbolt))) or ((EnemiesCount8ySplash > 3 or not S.GlacialSpike:IsAvailable()) and (Player:PrevGCDP(1, S.FrozenOrb) or Player:FrozenOrbGroundAoeRemains() > 5))) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.BloodoftheEnemy)) then return "blood_of_the_enemy essences 4"; end
  end
  --purifying_blast,if=buff.rune_of_power.down|active_enemies>3
  if S.PurifyingBlast:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or EnemiesCount8ySplash > 3) then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.PurifyingBlast)) then return "purifying_blast essences 5"; end
  end
  --ripple_in_space,if=buff.rune_of_power.down|active_enemies>3
  if S.RippleInSpace:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or EnemiesCount8ySplash > 3) then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space essences 6"; end
  end
  --concentrated_flame,line_cd=6,if=buff.rune_of_power.down
  if S.ConcentratedFlame:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff)) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.ConcentratedFlame)) then return "concentrated_flame essences 7"; end
  end
  --reaping_flames,if=buff.rune_of_power.down
  if (Player:BuffDown(S.RuneofPowerBuff)) then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  end
  --the_unbound_force,if=buff.reckless_force.up
  if S.TheUnboundForce:IsCastable() and (Player:BuffUp(S.RecklessForceBuff)) then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.TheUnboundForce)) then return "the_unbound_force essences 9"; end
  end
  --worldvein_resonance,if=buff.rune_of_power.down|active_enemies>3
  if S.WorldveinResonance:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) or EnemiesCount8ySplash > 3) then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance essences 10"; end
  end
end

local function Cooldowns ()
  --mirrors_of_torment,if=soulbind.wasteland_propriety.enabled - Covenant
  if S.MirrorsofTorment:IsCastable() and S.WastelandPropriety:IsAvailable() then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment cd 1"; end
  end
  --deathborne - Covenant
  if S.Deathborne:IsCastable() then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne cd 2"; end
  end
  --rune_of_power,if=cooldown.icy_veins.remains>15&buff.rune_of_power.down - CD
  if S.RuneofPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and (S.IcyVeins:CooldownRemains() > 15 or Target:TimeToDie() < S.RuneofPower:BaseDuration() + S.RuneofPower:CastTime() + Player:GCD()) then
    if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneOfPower) then return "rune_of_power cd 3"; end
  end
  --icy_veins,if=buff.rune_of_power.down - CD
  if S.IcyVeins:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) then
    if HR.Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cd 4"; end
  end
  --time_warp,if=runeforge.temporal_warp.equipped&time>10&(prev_off_gcd.icy_veins|target.time_to_die<30) - CD
  -- NYI legendaries
  --[[ if S.TimeWarp:IsCastable() and Player:BuffDown(S.TimeWarp) then
    if HR.Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp cd 5"; end
  end ]]
  --potion,if=prev_gcd.1.icy_veins|target.time_to_die<30
  -- TODO : potion
  --[[ if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and (Player:PrevGCDP(1, S.IcyVeins) or Target:TimeToDie() < 30) then
    if HR.CastSuggested(I.PotionofFocusedResolve) then return "potion cd 6"; end
  end ]]
  --use_item,name=balefire_branch - Trinket
  if I.BalefireBranch:IsEquipped() and I.BalefireBranch:IsReady() and Settings.Commons.UseTrinkets then
    if HR.Cast(I.BalefireBranch, nil, Settings.Commons.TrinketDisplayStyle) then return "balefire_branch cd 7"; end
  end
  --use_items - Trinket
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse and Settings.Commons.UseTrinkets then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() .. " cd 8" end
  end
  --use_item,name=pocketsized_computation_device - Trinket
  if Everyone.PSCDEquipReady() and Settings.Commons.UseTrinkets then
    if HR.Cast(I.PocketsizedComputationDevice, nil, Settings.Commons.TrinketDisplayStyle, not Target:IsInRange(40)) then return "pocketsized_computation_device cd 9"; end
  end
  --blood_fury - Racial
  if S.BloodFury:IsCastable() then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd 10"; end
  end
  --berserking - Racial
  if S.Berserking:IsCastable() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd 11"; end
  end
  --lights_judgment - Racial
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cd 12"; end
  end
  --fireblood - Racial
  if S.Fireblood:IsCastable() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd 13"; end
  end
  --ancestral_call - Racial
  if S.AncestralCall:IsCastable() then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd 14"; end
  end
  --bag_of_tricks - Racial
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cd 15"; end
  end
end

local function Movement ()
  -- blink,if=movement.distance>10
  if S.Blink:IsCastable() and (not Target:IsSpellInRange(S.Frostbolt)) then
    if HR.Cast(S.Blink) then return "blink mvt 1"; end
  end
  -- ice_floes,if=buff.ice_floes.down
  if S.IceFloes:IsCastable() and (Player:BuffDown(S.IceFloes)) then
    if HR.Cast(S.IceFloes, Settings.Frost.OffGCDasOffGCD.IceFloes) then return "ice_floes mvt 2"; end
  end
  -- arcane_explosion,if=mana.pct>30&active_enemies>=2 
  -- NYI legendaries disciplinary_command ?
  if S.ArcaneExplosion:IsCastable() and Target:IsSpellInRange(S.ArcaneExplosion) and Player:ManaPercentageP() > 30 and EnemiesCount10yMelee >= 2 then
    if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion mvt 3"; end
  end
  -- fire_blast
  -- NYI legendaries disciplinary_command ?
  if S.FireBlast:IsCastable() then
    if HR.Cast(S.FireBlast) then return "fire_blast mvt 4"; end
  end
  -- ice_lance
  if S.IceLance:IsCastable() then
    if HR.Cast(S.IceLance) then return "ice_lance mvt 5"; end
  end
end

local function Aoe ()
  --frozen_orb
  if S.FrozenOrb:IsCastable() then
    if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsSpellInRange(S.FrozenOrb)) then return "frozen_orb aoe 1"; end
  end
  --blizzard
  if S.Blizzard:IsCastable() then
    if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 2"; end
  end
  --flurry,if=(remaining_winters_chill=0|debuff.winters_chill.down)&(prev_gcd.1.ebonbolt|buff.brain_freeze.react&buff.fingers_of_frost.react=0)
  if S.Flurry:IsCastable() and Target:DebuffStack(S.WintersChillDebuff) == 0 and (Player:IsCasting(S.Ebonbolt) or (Player:BuffUp(S.BrainFreezeBuff) and Player:BuffStack(S.FingersofFrostBuff) == 0)) then
    if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 3"; end
  end
  --ice_nova
  if S.IceNova:IsCastable() and EnemiesCount8ySplash >= 5 then
    if HR.Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 4"; end
  end
  --comet_storm
  if S.CometStorm:IsCastable() and EnemiesCount6ySplash >= 5 then
    if HR.Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe 5"; end
  end
  --ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time|remaining_winters_chill&debuff.winters_chill.remains>travel_time
  if S.IceLance:IsCastable() and EnemiesCount8ySplash >= 2 and (Player:BuffStack(S.FingersofFrostBuff) > 0 or Target:DebuffRemains(S.Frostbite) > S.IceLance:TravelTime() or (Target:DebuffStack(S.WintersChillDebuff) > 1 and Target:DebuffRemains(S.WintersChillDebuff) > S.IceLance:TravelTime())) then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 6"; end
  end
  --radiant_spark
  if S.RadiantSpark:IsCastable() then
    if HR.Cast(S.RadiantSpark, nil, nil, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark aoe 7"; end
  end
  --shifting_power
  if S.ShiftingPower:IsCastable() then
    if HR.Cast(S.ShiftingPower, nil, nil, not Target:IsSpellInRange(S.ShiftingPower)) then return "shifting_power aoe 8"; end
  end
  --mirrors_of_torment
  if S.MirrorsofTorment:IsCastable() then
    if HR.Cast(S.MirrorsofTorment, nil, nil, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment aoe 9"; end
  end
  --frost_nova,if=runeforge.grisly_icicle.equipped&target.level<=level&debuff.frozen.down
  -- NYI legendaries
  --[[   if S.FrostNova:IsCastable() and Target:IsSpellInRange(S.FrostNova) then
    if HR.Cast(S.FrostNova) then return "frost_nova aoe 10"; end
  end ]]
  --fire_blast,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down
  -- NYI legendaries
  --[[ if S.FireBlast:IsCastable() then
    if HR.Cast(S.FireBlast) then return "fire_blast aoe 11"; end
  end ]]
  --arcane_explosion,if=mana.pct>30&!runeforge.cold_front.equipped
  -- NYI legendaries
  --[[   if S.ArcaneExplosion:IsCastable() and Target:IsSpellInRange(S.ArcaneExplosion) and Player:ManaPercentageP() > 30 then
    if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion aoe 12"; end
  end ]]
  --ebonbolt
  if S.Ebonbolt:IsCastable() and EnemiesCount8ySplash >= 2 then
    if HR.Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt aoe 13"; end
  end
  --frostbolt
  if S.Frostbolt:IsCastable() then
    if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 14"; end
  end
  --ice_lance
  if S.IceLance:IsCastable() then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 15"; end
  end
end

local function Single ()
  --flurry,if=(remaining_winters_chill=0|debuff.winters_chill.down)&(prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.radiant_spark|prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt|(debuff.mirrors_of_torment.up|buff.expanded_potential.react|buff.freezing_winds.up)&buff.fingers_of_frost.react=0))
  -- NYI legendaries
  if S.Flurry:IsCastable() and Target:DebuffStack(S.WintersChillDebuff) == 0 and (Player:IsCasting(S.Ebonbolt) or Player:BuffUp(S.BrainFreezeBuff) and (Player:IsCasting(S.Ebonbolt) or Player:IsCasting(S.GlacialSpike) or Player:IsCasting(S.FrostBolt) or ((Target:DebuffStack(S.MirrorsofTorment) > 0 or Player:BuffUp(S.FreezingRain)) and Player:BuffStack(S.FingersofFrostBuff) == 0))) then
    if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single 1"; end
  end
  --frozen_orb
  if S.FrozenOrb:IsCastable() then
    if HR.Cast(S.FrozenOrb, nil, nil, not Target:IsInRange(40)) then return "frozen_orb single 2"; end
  end
  --blizzard,if=buff.freezing_rain.up|active_enemies>=3|active_enemies>=2&!runeforge.cold_front.equipped
  -- NYI legendaries
  if S.Blizzard:IsCastable() and (Player:BuffUp(S.FreezingRain) or EnemiesCount16ySplash >= 3) then
    if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single 3"; end
  end
  --ray_of_frost,if=remaining_winters_chill=1&debuff.winters_chill.remains
  if S.RayofFrost:IsCastable() and Target:DebuffStack(S.WintersChillDebuff) == 1 then
    if HR.Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single 4"; end
  end
  --glacial_spike,if=remaining_winters_chill&debuff.winters_chill.remains>cast_time+travel_time
  if S.GlacialSpike:IsCastable() and Target:DebuffStack(S.WintersChillDebuff) > 0 and Target:DebuffRemains(S.WintersChillDebuff) > S.GlacialSpike:CastTime() + S.GlacialSpike:TravelTime() then
    if HR.Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 5"; end
  end
  --ice_lance,if=remaining_winters_chill&remaining_winters_chill>buff.fingers_of_frost.react&debuff.winters_chill.remains>travel_time
  if S.IceLance:IsCastable() and Target:DebuffStack(S.WintersChillDebuff) > 0 and Target:DebuffStack(S.WintersChillDebuff) > Player:BuffStack(S.FingersofFrostBuff) and Target:DebuffRemains(S.WintersChillDebuff) > S.IceLance:TravelTime() then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 6"; end
  end
  --comet_storm
  if S.CometStorm:IsCastable() then
    if HR.Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single 7"; end
  end
  --ice_nova
  if S.IceNova:IsCastable() then
    if HR.Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova single 8"; end
  end
  --radiant_spark,if=buff.freezing_winds.up&active_enemies=1
  -- NYI legendaries
  --[[ if S.RadiantSpark:IsCastable() then
    if HR.Cast(S.RadiantSpark, nil, nil, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 9"; end
  end ]]
  --ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time
  if S.IceLance:IsCastable() and (Player:BuffStack(S.FingersofFrostBuff) > 0 or Target:DebuffRemains(S.Freeze) > S.IceLance:TravelTime()) then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 10"; end
  end
  --ebonbolt
  if S.Ebonbolt:IsCastable() then
    if HR.Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt single 11"; end
  end
  --radiant_spark,if=(!runeforge.freezing_winds.equipped|active_enemies>=2)&(buff.brain_freeze.react|soulbind.combat_meditation.enabled)
  -- NYI legendaries
  --[[ if S.RadiantSpark:IsCastable() then
    if HR.Cast(S.RadiantSpark, nil, nil, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 12"; end
  end ]]
  --shifting_power,if=active_enemies>=3
  if S.ShiftingPower:IsCastable() and EnemiesCount18yMelee >= 3 then
    if HR.Cast(S.ShiftingPower, nil, Settings.Commons.CovenantDisplayStyle) then return "shifting_power single 13"; end
  end
  --shifting_power,line_cd=60,if=(soulbind.field_of_blossoms.enabled|soulbind.grove_invigoration.enabled)&(!talent.rune_of_power.enabled|buff.rune_of_power.down&cooldown.rune_of_power.remains>16)
  if S.ShiftingPower:IsCastable() then
    if HR.Cast(S.ShiftingPower, nil, Settings.Commons.CovenantDisplayStyle) then return "shifting_power single 14"; end
  end
  --mirrors_of_torment
  if S.MirrorsofTorment:IsCastable() then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment single 15"; end
  end
  --frost_nova,if=runeforge.grisly_icicle.equipped&target.level<=level&debuff.frozen.down
  -- NYI legendaries
  --[[   if S.FrostNova:IsCastable() and Target:IsSpellInRange(S.FrostNova) then
    if HR.Cast(S.FrostNova) then return "frost_nova single 16"; end
  end ]]
  --arcane_explosion,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_arcane.down
  -- NYI legendaries
  --[[   if S.ArcaneExplosion:IsCastable() and Target:IsSpellInRange(S.ArcaneExplosion) and Player:ManaPercentageP() > 30 then
    if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion single 17"; end
  end ]]
  --fire_blast,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down
  -- NYI legendaries
  --[[ if S.FireBlast:IsCastable() then
    if HR.Cast(S.FireBlast) then return "fire_blast single 18"; end
  end ]]
  --glacial_spike,if=buff.brain_freeze.react
  if S.GlacialSpike:IsCastable() and Player:BuffUp(S.BrainFreezeBuff) then
    if HR.Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 19"; end
  end
  --frostbolt
  if S.Frostbolt:IsCastable() then
    if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt single 20"; end
  end
  --ice_lance
  if S.IceLance:IsCastable() then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 21"; end
  end
end

--- ======= ACTION LISTS =======
local function APL ()
  EnemiesCount6ySplash = Target:GetEnemiesInSplashRangeCount(6)
  EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
  EnemiesCount30ySplash = Target:GetEnemiesInSplashRangeCount(30)
  Enemies10yMelee = Player:GetEnemiesInMeleeRange(10)
  EnemiesCount10yMelee = #Enemies10yMelee
  Enemies12yMelee = Player:GetEnemiesInMeleeRange(12)
  EnemiesCount12yMelee = #Enemies12yMelee
  Enemies18yMelee = Player:GetEnemiesInMeleeRange(18)
  EnemiesCount18yMelee = #Enemies18yMelee
  Mage.IFTracker()

  --call precombat
  if not Player:AffectingCombat() and (not Player:IsCasting() or Player:IsCasting(S.WaterElemental)) then
    ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    --counterspell
    ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    --call_action_list,name=cds
    if HR.CDsON() then
      ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=essences
    if HR.CDsON() then
      ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=aoe,if=active_enemies>=5
    -- TODO : see if the splash 16 range is good
    if HR.AoEON() and EnemiesCount16ySplash >= 5 then
      ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=single,if=active_enemies<5
    if not HR.AoEON() or EnemiesCount16ySplash < 5 then
      ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=movement
    -- TODO : movement
  end
end

local function Init ()

end

HR.SetAPL(64, APL, Init)
