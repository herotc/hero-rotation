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
local Cast       = HR.Cast
local CastLeft   = HR.CastLeft
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
local Mage       = HR.Commons.Mage
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local mathmax    = math.max

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Frost
local I = Item.Mage.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- TWW Trinkets
  I.ArazsRitualForge:ID(),
  I.BurstofKnowledge:ID(),
  I.FlarendosPilotLight:ID(),
  I.FunhouseLens:ID(),
  I.HouseOfCards:ID(),
  I.ImperfectAscendancySerum:ID(),
  I.LilyOfTheEternalWeave:ID(),
  I.MereldarsToll:ID(),
  I.QuickwickCandlestick:ID(),
  I.SignetOfThePriory:ID(),
  I.SpymastersWeb:ID(),
  I.TreacherousTransmitter:ID(),
  -- TWW S2 Prior Expansion Trinkets
  I.RatfangToxin:ID(),
  I.SoullettingRuby:ID(),
  I.SunbloodAmethyst:ID(),
  -- TWW S2 Prior Expansion Items
  I.NeuralSynapseEnhancer:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  CommonsDS = HR.GUISettings.APL.Mage.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Mage.CommonsOGCD,
  Frost = HR.GUISettings.APL.Mage.Frost
}

--- ===== Rotation Variables =====
local Bolt = S.FrostfireBolt:IsAvailable() and S.FrostfireBolt or S.Frostbolt
local EnemiesCount8ySplash, EnemiesCount16ySplash --Enemies arround target
local Enemies16ySplash
local RemainingWintersChill = 0
local Icicles = 0
local PlayerMaxLevel = 80 -- TODO: Pull this value from Enum instead.
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  S.Frostbolt:RegisterInFlightEffect(228597)
  S.Frostbolt:RegisterInFlight()
  S.FrostfireBolt:RegisterInFlight()
  S.FrozenOrb:RegisterInFlightEffect(84721)
  S.FrozenOrb:RegisterInFlight()
  S.Flurry:RegisterInFlightEffect(228354)
  S.Flurry:RegisterInFlight()
  S.GlacialSpike:RegisterInFlightEffect(228600)
  S.GlacialSpike:RegisterInFlight()
  S.IceLance:RegisterInFlightEffect(228598)
  S.IceLance:RegisterInFlight()
  Bolt = S.FrostfireBolt:IsAvailable() and S.FrostfireBolt or S.Frostbolt
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.Frostbolt:RegisterInFlightEffect(228597)
S.Frostbolt:RegisterInFlight()
S.FrostfireBolt:RegisterInFlight()
S.FrozenOrb:RegisterInFlightEffect(84721)
S.FrozenOrb:RegisterInFlight()
S.Flurry:RegisterInFlightEffect(228354)
S.Flurry:RegisterInFlight()
S.GlacialSpike:RegisterInFlightEffect(228600)
S.GlacialSpike:RegisterInFlight()
S.IceLance:RegisterInFlightEffect(228598)
S.IceLance:RegisterInFlight()

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
  RemainingWintersChill = 0
end, "PLAYER_REGEN_ENABLED")

--- ===== Helper Functions =====
local function Freezable(Tar)
  if Tar == nil then Tar = Target end
  return not Tar:IsInBossList() or Tar:Level() < PlayerMaxLevel + 3
end

local function CalculateWintersChill(enemies)
  if S.WintersChillDebuff:AuraActiveCount() == 0 then return 0 end
  local WCStacks = 0
  for _, CycleUnit in pairs(enemies) do
    WCStacks = WCStacks + CycleUnit:DebuffStack(S.WintersChillDebuff)
  end
  return WCStacks
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterWCStacks(TargetUnit)
  -- target_if=min/max:debuff.winters_chill.stack
  return (TargetUnit:DebuffStack(S.WintersChillDebuff))
end

--- ===== CastCycle Filter Functions =====
local function EvaluateCycleWintersChill(TargetUnit)
  -- target_if=debuff.winters_chill.down
  return TargetUnit:DebuffDown(S.WintersChillDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- arcane_intellect
  -- Note: Moved to top of APL.
  -- snapshot_stats
  -- variable,name=treacherous_transmitter_precombat_cast,value=12,if=equipped.treacherous_transmitter
  -- Note: Unused variable.
  -- use_item,name=treacherous_transmitter
  if I.TreacherousTransmitter:IsEquippedAndReady() then
    if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter precombat 2"; end
  end
  -- use_item,name=ingenious_mana_battery,target=self
  if I.IngeniousManaBattery:IsEquippedAndReady() then
    if Cast(I.IngeniousManaBattery, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "ingenious_mana_battery precombat 4"; end
  end
  -- blizzard,if=active_enemies>=3
  -- Note: Can't check active_enemies in Precombat
  -- frostbolt,if=active_enemies<=2
  if Bolt:IsCastable() and not Player:IsCasting(Bolt) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt precombat 6"; end
  end
end

local function CDs()
  -- flurry,if=time=0&active_enemies<=2&talent.splinterstorm
  -- Note: Can't get here at time=0.
  -- icy_veins
  if S.IcyVeins:IsCastable() then
    if Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cds 2"; end
  end
  -- potion,if=buff.icy_veins.remains>15|fight_remains<35
  if Settings.Commons.Enabled.Potions and (Player:BuffRemains(S.IcyVeinsBuff) > 15 or BossFightRemains < 35) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 4"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- Note: This condition is used in multiple lines below, so let's just check once.
    local IVFR = Player:BuffRemains(S.IcyVeinsBuff) > 10 or BossFightRemains < 20
    -- use_item,name=treacherous_transmitter,if=fight_remains<32+20*equipped.spymasters_web|prev_off_gcd.icy_veins|(cooldown.icy_veins.remains<12|cooldown.icy_veins.remains<22&cooldown.shifting_power.remains<10)
    if I.TreacherousTransmitter:IsEquippedAndReady() and (BossFightRemains < 32 + 20 * num(I.SpymastersWeb:IsEquipped()) or Player:PrevOffGCDP(1, S.IcyVeins) or (S.IcyVeins:CooldownRemains() < 12 or S.IcyVeins:CooldownRemains() < 22 and S.ShiftingPower:CooldownRemains() < 10)) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter cds 6"; end
    end
    -- do_treacherous_transmitter_task,if=fight_remains<18|(buff.cryptic_instructions.remains<?buff.realigning_nexus_convergence_divergence.remains<?buff.errant_manaforge_emission.remains)<(action.shifting_power.execute_time+1*talent.ray_of_frost)
    -- TODO
    -- use_item,name=spymasters_web,if=fight_remains<20|buff.icy_veins.remains<19&(fight_remains<105|buff.spymasters_report.stack>=32)&(buff.icy_veins.remains>15|trinket.treacherous_transmitter.cooldown.remains>50)
    if I.SpymastersWeb:IsEquippedAndReady() and (BossFightRemains < 20 or Player:BuffRemains(S.IcyVeinsBuff) < 19 and (FightRemains < 105 or Player:BuffStack(S.SpymastersReportBuff) >= 32) and (Player:BuffRemains(S.IcyVeinsBuff) > 15 or I.TreacherousTransmitter:IsEquipped() and I.TreacherousTransmitter:CooldownRemains() > 50)) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web cds 8"; end
    end
    -- use_item,name=arazs_ritual_forge
    if I.ArazsRitualForge:IsEquippedAndReady() then
      if Cast(I.ArazsRitualForge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "arazs_ritual_forge cds 10"; end
    end
    -- use_item,name=signet_of_the_priory
    if I.SignetOfThePriory:IsEquippedAndReady() then
      if Cast(I.SignetOfThePriory, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "signet_of_the_priory cds 12"; end
    end
    -- use_item,name=sunblood_amethyst,if=buff.icy_veins.remains>10|fight_remains<20
    if I.SunbloodAmethyst:IsEquippedAndReady() and (IVFR) then
      if Cast(I.SunbloodAmethyst, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "sunblood_amethyst cds 14"; end
    end
    -- use_item,name=lily_of_the_eternal_weave,if=buff.icy_veins.remains>10|fight_remains<20
    if I.LilyOfTheEternalWeave:IsEquippedAndReady() and (IVFR) then
      if Cast(I.LilyOfTheEternalWeave, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "lily_of_the_eternal_weave cds 16"; end
    end
    -- use_item,name=funhouse_lens,if=buff.icy_veins.remains>10|fight_remains<20
    if I.FunhouseLens:IsEquippedAndReady() and (IVFR) then
      if Cast(I.FunhouseLens, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "funhouse_lens cds 18"; end
    end
    -- use_item,name=mereldars_toll,if=buff.icy_veins.remains>10|fight_remains<15
    if I.MereldarsToll:IsEquippedAndReady() and (Player:BuffRemains(S.IcyVeinsBuff) > 10 or BossFightRemains < 15) then
      if Cast(I.MereldarsToll, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "mereldars_toll cds 20"; end
    end
    -- use_item,name=house_of_cards,if=buff.icy_veins.remains>10|fight_remains<20
    if I.HouseOfCards:IsEquippedAndReady() and (IVFR) then
      if Cast(I.HouseOfCards, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "house_of_cards cds 22"; end
    end
    -- use_item,name=flarendos_pilot_light
    if I.FlarendosPilotLight:IsEquippedAndReady() then
      if Cast(I.FlarendosPilotLight, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "flarendos_pilot_light cds 24"; end
    end
    -- use_item,name=soulletting_ruby
    if I.SoullettingRuby:IsEquippedAndReady() then
      if Cast(I.SoullettingRuby, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "soulletting_ruby cds 26"; end
    end
    -- use_item,name=quickwick_candlestick,if=buff.icy_veins.remains>10|fight_remains<20
    if I.QuickwickCandlestick:IsEquippedAndReady() and (IVFR) then
      if Cast(I.QuickwickCandlestick, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "quickwick_candlestick cds 28"; end
    end
    -- use_item,name=imperfect_ascendancy_serum,if=buff.icy_veins.remains>10|fight_remains<20
    if I.ImperfectAscendancySerum:IsEquippedAndReady() and (IVFR) then
      if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum cds 30"; end
    end
    -- use_item,name=burst_of_knowledge,if=buff.icy_veins.remains>10|fight_remains<20
    if I.BurstofKnowledge:IsEquippedAndReady() and (IVFR) then
      if Cast(I.BurstofKnowledge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "burst_of_knowledge cds 32"; end
    end
    -- use_item,name=ratfang_toxin,if=time>10
    if I.RatfangToxin:IsEquippedAndReady() and (HL.CombatTime() > 10) then
      if Cast(I.RatfangToxin, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "ratfang_toxin cds 34"; end
    end
  end
  -- use_item,name=neural_synapse_enhancer,if=active_enemies<=2|prev_gcd.1.comet_storm|fight_remains<20
  if Settings.Commons.Enabled.Items and I.NeuralSynapseEnhancer:IsEquippedAndReady() and (EnemiesCount8ySplash <= 2 or Player:PrevGCDP(1, S.CometStorm) or BossFightRemains < 20) then
    if Cast(I.NeuralSynapseEnhancer, nil, Settings.CommonsDS.DisplayStyle.Items) then return "neural_synapse_enhancer cds 36"; end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " cds 38"; end
      end
    end
  end
  -- flurry,if=time=0&active_enemies<=2
  -- frozen_orb,if=time=0&active_enemies>=3
  if CDsON() then
    -- blood_fury
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 40"; end
    end
    -- berserking,if=buff.icy_veins.remains>10|fight_remains<15
    if S.Berserking:IsCastable() and (Player:BuffRemains(S.IcyVeinsBuff) > 10 or BossFightRemains < 15) then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 42"; end
    end
    -- fireblood
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 44"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 46"; end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.power_infusion.down
  -- invoke_external_buff,name=blessing_of_summer,if=buff.blessing_of_summer.down
  -- Note: Not handling external buffs.
end

local function Movement()
  -- ice_floes,if=buff.ice_floes.down
  if S.IceFloes:IsCastable() and (Player:BuffDown(S.IceFloes)) then
    if Cast(S.IceFloes, Settings.Frost.GCDasOffGCD.IceFloes) then return "ice_floes movement 2"; end
  end
  -- any_blink,if=movement.distance>5
  -- Note: Not handling blink.
  -- flurry
  if S.Flurry:IsCastable() then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry movement 4"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb movement 6"; end
  end
  -- comet_storm,if=talent.splinterstorm
  if S.CometStorm:IsCastable() and (S.Splinterstorm:IsAvailable()) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm movement 8"; end
  end
  -- ice_nova
  if S.IceNova:IsCastable() then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova movement 10"; end
  end
  -- ice_lance
  if S.IceLance:IsReady() then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance movement 12"; end
  end
end

local function FFAoE()
  -- cone_of_cold,if=talent.coldest_snap&prev_gcd.1.comet_storm
  if S.ConeofCold:IsCastable() and (S.ColdestSnap:IsAvailable() and Player:PrevGCDP(1, S.CometStorm)) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold ff_aoe 2"; end
  end
  -- freeze,if=freezable&time-action.cone_of_cold.last_used>8&(prev_gcd.1.glacial_spike&remaining_winters_chill=0&debuff.winters_chill.down|prev_gcd.1.comet_storm)
  if Pet:IsActive() and S.Freeze:IsCastable() and (Freezable() and S.ConeofCold:TimeSinceLastCast() > 8 and (Player:PrevGCDP(1, S.GlacialSpike) and RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) or Player:PrevGCDP(1, S.CometStorm))) then
    if Cast(S.Freeze, nil, nil, not Target:IsSpellInRange(S.Freeze)) then return "freeze ff_aoe 4"; end
  end
  -- ice_nova,if=!prev_off_gcd.freeze&freezable&time-action.cone_of_cold.last_used>8&(prev_gcd.1.glacial_spike&remaining_winters_chill=0&debuff.winters_chill.down|prev_gcd.1.comet_storm)
  if S.IceNova:IsCastable() and (not Player:PrevOffGCDP(1, S.Freeze) and Freezable() and S.ConeofCold:TimeSinceLastCast() > 8 and (Player:PrevGCDP(1, S.GlacialSpike) and RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) or Player:PrevGCDP(1, S.CometStorm))) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova ff_aoe 6"; end
  end
  -- flurry,if=cooldown_react&!prev_off_gcd.freeze&remaining_winters_chill=0&debuff.winters_chill.down&prev_gcd.1.glacial_spike
  if S.Flurry:IsCastable() and (not Player:PrevOffGCDP(1, S.Freeze) and RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ff_aoe 8"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb ff_aoe 10"; end
  end
  -- blizzard,if=talent.ice_caller|talent.freezing_rain
  if S.Blizzard:IsCastable() and (S.IceCaller:IsAvailable() or S.FreezingRain:IsAvailable()) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard ff_aoe 12"; end
  end
  -- frostfire_bolt,if=talent.deaths_chill&buff.icy_veins.up&(buff.deaths_chill.stack<9|buff.deaths_chill.stack=9&!action.frostfire_bolt.in_flight)
  if Bolt:IsReady() and (S.DeathsChill:IsAvailable() and Player:BuffUp(S.IcyVeinsBuff) and (Player:BuffStack(S.DeathsChillBuff) < 9 or Player:BuffStack(S.DeathsChillBuff) == 9 and not Bolt:InFlight())) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt ff_aoe 14"; end
  end
  -- ice_lance,if=talent.deaths_chill&buff.excess_fire.stack=2&cooldown.comet_storm.ready
  if S.IceLance:IsReady() and (S.DeathsChill:IsAvailable() and Player:BuffStack(S.ExcessFireBuff) == 2 and S.CometStorm:CooldownUp()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ff_aoe 16"; end
  end
  -- comet_storm,if=cooldown.cone_of_cold.remains>12|cooldown.cone_of_cold.ready
  if S.CometStorm:IsCastable() and (S.ConeofCold:CooldownRemains() > 12 or S.ConeofCold:CooldownUp()) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm ff_aoe 18"; end
  end
  -- ray_of_frost,if=talent.splintering_ray&remaining_winters_chill=2
  if S.RayofFrost:IsCastable() and (S.SplinteringRay:IsAvailable() and RemainingWintersChill == 2) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost ff_aoe 20"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike ff_aoe 22"; end
  end
  -- flurry,if=cooldown_react&buff.excess_frost.up
  if S.Flurry:IsCastable() and (Player:BuffUp(S.ExcessFrostBuff)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ff_aoe 24"; end
  end
  -- shifting_power,if=(!equipped.arazs_ritual_forge|buff.icy_veins.down)&cooldown.icy_veins.remains>8&(cooldown.comet_storm.remains>8|!talent.comet_storm)&cooldown.blizzard.remains>6*gcd.max
  if CDsON() and S.ShiftingPower:IsCastable() and ((not I.ArazsRitualForge:IsEquipped() or Player:BuffDown(S.IcyVeinsBuff)) and S.IcyVeins:CooldownRemains() > 8 and (S.CometStorm:CooldownRemains() > 8 or not S.CometStorm:IsAvailable()) and S.Blizzard:CooldownRemains() > 6 * GCDMax) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ff_aoe 26"; end
  end
  -- frostfire_bolt,if=buff.frostfire_empowerment.react&!buff.excess_fire.up
  if Bolt:IsReady() and (Player:BuffUp(S.FrostfireEmpowermentBuff) and Player:BuffDown(S.ExcessFireBuff)) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt ff_aoe 28"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ff_aoe 30"; end
  end
  -- ice_lance,if=remaining_winters_chill
  if S.IceLance:IsReady() and (RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ff_aoe 32"; end
  end
  -- frostfire_bolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt ff_aoe 34"; end
  end
  -- call_action_list,name=movement
  local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
end

local function FFCleave()
  -- flurry,target_if=debuff.winters_chill.down,if=cooldown_react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostfire_bolt|prev_gcd.1.comet_storm)
  if S.Flurry:IsCastable() and (S.GlacialSpike:IsAvailable() or S.FrostfireBolt:IsAvailable() or S.CometStorm:IsAvailable()) then
    if Everyone.CastCycle(S.Flurry, Enemies16ySplash, EvaluateCycleWintersChill, not Target:IsSpellInRange(S.Flurry), Settings.Frost.GCDasOffGCD.Flurry) then return "flurry ff_cleave 2"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastable() then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm ff_cleave 4"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike ff_cleave 6"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb ff_cleave 8"; end
  end
  -- blizzard,if=buff.icy_veins.down&buff.freezing_rain.up
  if S.Blizzard:IsCastable() and (Player:BuffDown(S.IcyVeinsBuff) and Player:BuffUp(S.FreezingRainBuff)) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard ff_cleave 10"; end
  end
  -- shifting_power,if=(!equipped.arazs_ritual_forge|buff.icy_veins.down)&cooldown.icy_veins.remains>8&(cooldown.comet_storm.remains>8|!talent.comet_storm)
  if CDsON() and S.ShiftingPower:IsCastable() and ((not I.ArazsRitualForge:IsEquipped() or Player:BuffDown(S.IcyVeinsBuff)) and S.IcyVeins:CooldownRemains() > 8 and (S.CometStorm:CooldownRemains() > 8 or not S.CometStorm:IsAvailable())) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ff_cleave 12"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ff_cleave 14"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=!talent.deaths_chill&remaining_winters_chill=2
  if S.IceLance:IsReady() and (not S.DeathsChill:IsAvailable() and RemainingWintersChill == 2) then
    if Everyone.CastTargetIf(S.IceLance, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ff_cleave 16"; end
  end
  -- frostfire_bolt,target_if=min:debuff.winters_chill.stack
  if Bolt:IsReady() then
    if Everyone.CastTargetIf(Bolt, Enemies16ySplash, "min", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt ff_cleave 18"; end
  end
  -- call_action_list,name=movement
  local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
end

local function FFST()
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&prev_gcd.1.glacial_spike
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ff_st 2"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&(buff.icicles.react>=3|!talent.glacial_spike)
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and (Icicles >= 3 or not S.GlacialSpike:IsAvailable())) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ff_st 4"; end
  end
  -- comet_storm,if=remaining_winters_chill
  if S.CometStorm:IsCastable() and (RemainingWintersChill > 0) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm ff_st 6"; end
  end
  -- ray_of_frost,if=remaining_winters_chill=2
  if S.RayofFrost:IsCastable() and (RemainingWintersChill == 2) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost ff_st 8"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike ff_st 10"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb ff_st 12"; end
  end
  -- shifting_power,if=(!equipped.arazs_ritual_forge|buff.icy_veins.down)&cooldown.icy_veins.remains>8&(cooldown.comet_storm.remains>8|!talent.comet_storm)
  if CDsON() and S.ShiftingPower:IsCastable() and ((not I.ArazsRitualForge:IsEquipped() or Player:BuffDown(S.IcyVeinsBuff)) and S.IcyVeins:CooldownRemains() > 8 and (S.CometStorm:CooldownRemains() > 8 or not S.CometStorm:IsAvailable())) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ff_st 14"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ff_st 16"; end
  end
  -- ice_lance,if=remaining_winters_chill
  if S.IceLance:IsReady() and (RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ff_st 18"; end
  end
  -- frostfire_bolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt ff_st 18"; end
  end
  -- call_action_list,name=movement
  local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
end

local function FFSTBoltspam()
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&prev_gcd.1.glacial_spike
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ff_st_boltspam 2"; end
  end
  -- flurry,if=cooldown_react&prev_gcd.1.frostfire_bolt&buff.icicles.react>=3
  if S.Flurry:IsCastable() and (Player:PrevGCDP(1, Bolt) and Icicles >= 3) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ff_st_boltspam 4"; end
  end
  -- comet_storm,if=remaining_winters_chill
  if S.CometStorm:IsCastable() and (RemainingWintersChill > 0) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm ff_st_boltspam 6"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike ff_st_boltspam 8"; end
  end
  -- shifting_power,if=buff.icy_veins.down&cooldown.comet_storm.remains>8&cooldown.icy_veins.remains>8
  if CDsON() and S.ShiftingPower:IsCastable() and (Player:BuffDown(S.IcyVeinsBuff) and S.CometStorm:CooldownRemains() > 8 and S.IcyVeins:CooldownRemains() > 8) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ff_st_boltspam 10"; end
  end
  -- ice_lance,if=remaining_winters_chill=2
  if S.IceLance:IsReady() and (RemainingWintersChill == 2) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ff_st_boltspam 12"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react&buff.icicles.react=0
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) and Icicles == 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ff_st_boltspam 14"; end
  end
  -- frostfire_bolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt ff_st_boltspam 16"; end
  end
  -- call_action_list,name=movement
  local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
end

local function SSAoE()
  -- cone_of_cold,if=talent.coldest_snap&(prev_gcd.1.frozen_orb|cooldown.frozen_orb.remains>30)
  if S.ConeofCold:IsReady() and (S.ColdestSnap:IsAvailable() and (Player:PrevGCDP(1, S.FrozenOrb) or S.FrozenOrb:CooldownRemains() > 30)) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold ss_aoe 2"; end
  end
  -- ice_nova,if=(freezable|talent.unerring_proficiency)&active_enemies>=5&time-action.cone_of_cold.last_used<8&time-action.cone_of_cold.last_used>7
  if S.IceNova:IsCastable() and (Freezable() or S.UnerringProficiency:IsAvailable()) and EnemiesCount16ySplash >= 5 and S.ConeofCold:TimeSinceLastCast() < 8 and S.ConeofCold:TimeSinceLastCast() > 7 then
    if Cast(S.IceNova, nil, nil, not Target:IsInRange(12)) then return "ice_nova ss_aoe 4"; end
  end
  -- freeze,if=freezable&(prev_gcd.1.glacial_spike|!talent.glacial_spike&time-action.cone_of_cold.last_used>8)
  if Pet:IsActive() and S.Freeze:IsCastable() and (Freezable() and (Player:PrevGCDP(1, S.GlacialSpike) or not S.GlacialSpike:IsAvailable() and S.ConeofCold:TimeSinceLastCast() > 8)) then
    if Cast(S.Freeze, nil, nil, not Target:IsInRange(12)) then return "freeze ss_aoe 6"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&prev_gcd.1.glacial_spike
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_aoe 8"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&prev_gcd.1.frostbolt
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and Player:PrevGCDP(1, Bolt)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_aoe 10"; end
  end
  -- flurry,if=cooldown_react&buff.cold_front_ready.react
  if S.Flurry:IsCastable() and (Player:BuffUp(S.ColdFrontReadyBuff)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_aoe 12"; end
  end
  -- frozen_orb,if=cooldown_react
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb ss_aoe 14"; end
  end
  -- blizzard,if=talent.ice_caller|talent.freezing_rain
  if S.Blizzard:IsCastable() and (S.IceCaller:IsAvailable() or S.FreezingRain:IsAvailable()) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard ss_aoe 16"; end
  end
  -- comet_storm,if=talent.glacial_assault|buff.icy_veins.down
  if S.CometStorm:IsCastable() and (S.GlacialAssault:IsAvailable() or Player:BuffDown(S.IcyVeinsBuff)) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm ss_aoe 18"; end
  end
  -- ray_of_frost,if=talent.splintering_ray&buff.icy_veins.down&remaining_winters_chill
  if S.RayofFrost:IsCastable() and (S.SplinteringRay:IsAvailable() and Player:BuffDown(S.IcyVeinsBuff) and RemainingWintersChill > 0) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost ss_aoe 20"; end
  end
  -- shifting_power,if=talent.shifting_shards
  if S.ShiftingPower:IsCastable() and (S.ShiftingShards:IsAvailable()) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ss_aoe 22"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react=2&talent.glacial_spike
  if S.IceLance:IsReady() and (Player:BuffStack(S.FingersofFrostBuff) == 2 and S.GlacialSpike:IsAvailable()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_aoe 24"; end
  end
  -- glacial_spike,if=buff.icicles.react=5&(action.flurry.cooldown_react|remaining_winters_chill)
  if S.GlacialSpike:IsReady() and (Icicles == 5 and (S.Flurry:CooldownUp() or RemainingWintersChill > 0)) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike ss_aoe 26"; end
  end
  -- frostbolt,if=talent.deaths_chill&buff.icy_veins.up&(buff.deaths_chill.stack<6|buff.deaths_chill.stack=6&!action.frostbolt.in_flight)
  if Bolt:IsReady() and (S.DeathsChill:IsAvailable() and Player:BuffUp(S.IcyVeinsBuff) and (Player:BuffStack(S.DeathsChillBuff) < 6 or Player:BuffStack(S.DeathsChillBuff) == 6 and not Bolt:InFlight())) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt ss_aoe 28"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_aoe 30"; end
  end
  -- ice_lance,if=remaining_winters_chill
  if S.IceLance:IsReady() and (RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_aoe 32"; end
  end
  -- shifting_power,if=buff.icy_veins.down&cooldown.icy_veins.remains>8
  if CDsON() and S.ShiftingPower:IsCastable() and (Player:BuffDown(S.IcyVeinsBuff) and S.IcyVeins:CooldownRemains() > 8) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ss_aoe 34"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt ss_aoe 36"; end
  end
  -- call_action_list,name=movement
  local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
end

local function SSCleave()
  -- flurry,target_if=min:debuff.winters_chill.stack,if=cooldown_react&prev_gcd.1.glacial_spike
  if S.Flurry:IsCastable() and (Player:PrevGCDP(1, S.GlacialSpike)) then
    if Everyone.CastTargetIf(S.Flurry, Enemies16ySplash, "min", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.Flurry), Settings.Frost.GCDasOffGCD.Flurry) then return "flurry ss_cleave 2"; end
  end
  -- flurry,if=cooldown_react&debuff.winters_chill.down&remaining_winters_chill=0&prev_gcd.1.frostbolt
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and RemainingWintersChill == 0 and Player:PrevGCDP(1, Bolt)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_cleave 4"; end
  end
  -- flurry,if=cooldown_react&debuff.winters_chill.down&remaining_winters_chill=0&talent.shifting_shards&buff.cold_front_ready.react
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and RemainingWintersChill == 0 and S.ShiftingShards:IsAvailable() and Player:BuffUp(S.ColdFrontReadyBuff)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_cleave 6"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react=2&talent.glacial_spike
  if S.IceLance:IsReady() and (Player:BuffStack(S.FingersofFrostBuff) == 2 and S.GlacialSpike:IsAvailable()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_cleave 8"; end
  end
  -- frozen_orb,if=cooldown_react
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb ss_cleave 10"; end
  end
  -- comet_storm,if=buff.icy_veins.down&remaining_winters_chill&talent.shifting_shards
  if S.CometStorm:IsCastable() and (Player:BuffDown(S.IcyVeinsBuff) and RemainingWintersChill > 0 and S.ShiftingShards:IsAvailable()) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm ss_cleave 12"; end
  end
  -- shifting_power,if=!equipped.arazs_ritual_forge&cooldown.flurry.charges<2&cooldown.icy_veins.remains>8|talent.shifting_shards
  if CDsON() and S.ShiftingPower:IsCastable() and (not I.ArazsRitualForge:IsEquipped() and S.Flurry:Charges() < 2 and S.IcyVeins:CooldownRemains() > 8 or S.ShiftingShards:IsAvailable()) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ss_cleave 14"; end
  end
  -- glacial_spike,if=buff.icicles.react=5&(action.flurry.cooldown_react|remaining_winters_chill)
  if S.GlacialSpike:IsReady() and (Icicles == 5 and (S.Flurry:CooldownUp() or RemainingWintersChill > 0)) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike ss_cleave 16"; end
  end
  -- blizzard,if=buff.freezing_rain.up&talent.ice_caller
  if S.Blizzard:IsCastable() and (Player:BuffUp(S.FreezingRainBuff) and S.IceCaller:IsAvailable()) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard ss_cleave 18"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_cleave 20"; end
  end
  -- frostbolt,if=talent.deaths_chill&buff.icy_veins.up&(buff.deaths_chill.stack<8|buff.deaths_chill.stack=8&!action.frostbolt.in_flight)
  if Bolt:IsReady() and (S.DeathsChill:IsAvailable() and Player:BuffUp(S.IcyVeinsBuff) and (Player:BuffStack(S.DeathsChillBuff) < 8 or Player:BuffStack(S.DeathsChillBuff) == 8 and not Bolt:InFlight())) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt ss_cleave 22"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=remaining_winters_chill
  if S.IceLance:IsReady() and (RemainingWintersChill == 0) then
    if Everyone.CastTargetIf(S.IceLance, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_cleave 24"; end
  end
  -- shifting_power,if=equipped.arazs_ritual_forge&buff.icy_veins.down&cooldown.flurry.charges<2&cooldown.icy_veins.remains>8
  if CDsON() and S.ShiftingPower:IsCastable() and (I.ArazsRitualForge:IsEquipped() and Player:BuffDown(S.IcyVeinsBuff) and S.Flurry:Charges() < 2 and S.IcyVeins:CooldownRemains() > 8) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ss_cleave 26"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt ss_cleave 28"; end
  end
  -- call_action_list,name=movement
  local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
end

local function STSS()
  -- flurry,if=cooldown_react&debuff.winters_chill.down&remaining_winters_chill=0&prev_gcd.1.glacial_spike
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and RemainingWintersChill == 0 and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_st 2"; end
  end
  -- flurry,if=cooldown_react&debuff.winters_chill.down&remaining_winters_chill=0&(buff.icicles.react<5|!talent.glacial_spike)&prev_gcd.1.frostbolt
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and RemainingWintersChill == 0 and (Icicles < 5 or not S.GlacialSpike:IsAvailable()) and Player:PrevGCDP(1, Bolt)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_st 4"; end
  end
  -- frozen_orb,if=cooldown_react
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb ss_st 6"; end
  end
  -- comet_storm,if=buff.icy_veins.down&remaining_winters_chill&talent.shifting_shards
  if S.CometStorm:IsCastable() and (Player:BuffDown(S.IcyVeinsBuff) and RemainingWintersChill > 0 and S.ShiftingShards:IsAvailable()) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm ss_st 8"; end
  end
  -- ray_of_frost,if=buff.icy_veins.down&remaining_winters_chill=1
  if S.RayofFrost:IsCastable() and (Player:BuffDown(S.IcyVeinsBuff) and RemainingWintersChill == 1) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost ss_st 10"; end
  end
  -- shifting_power,if=!equipped.arazs_ritual_forge&cooldown.flurry.charges<2&cooldown.icy_veins.remains>8|talent.shifting_shards
  if CDsON() and S.ShiftingPower:IsCastable() and (not I.ArazsRitualForge:IsEquipped() and S.Flurry:Charges() < 2 and S.IcyVeins:CooldownRemains() > 8 or S.ShiftingShards:IsAvailable()) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ss_st 12"; end
  end
  -- glacial_spike,if=buff.icicles.react=5&(action.flurry.cooldown_react|remaining_winters_chill)
  if S.GlacialSpike:IsReady() and (Icicles == 5 and (S.Flurry:CooldownUp() or RemainingWintersChill > 0)) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike ss_st 14"; end
  end
  -- blizzard,if=buff.icy_veins.down&buff.freezing_rain.up&talent.ice_caller
  if S.Blizzard:IsCastable() and (Player:BuffDown(S.IcyVeinsBuff) and Player:BuffUp(S.FreezingRainBuff) and S.IceCaller:IsAvailable()) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard ss_st 16"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_st 18"; end
  end
  -- ice_lance,if=remaining_winters_chill
  if S.IceLance:IsReady() and (RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_st 20"; end
  end
  -- shifting_power,if=equipped.arazs_ritual_forge&buff.icy_veins.down&cooldown.flurry.charges<2&cooldown.icy_veins.remains>8
  if CDsON() and S.ShiftingPower:IsCastable() and (I.ArazsRitualForge:IsEquipped() and Player:BuffDown(S.IcyVeinsBuff) and S.Flurry:Charges() < 2 and S.IcyVeins:CooldownRemains() > 8) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ss_st 22"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt ss_st 24"; end
  end
  -- call_action_list,name=movement
  local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
end

--- ===== APL Main =====
local function APL()
  -- Enemies Update
  Enemies16ySplash = Target:GetEnemiesInSplashRange(16)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
  else
    EnemiesCount8ySplash = 1
    EnemiesCount16ySplash = 1
  end

  -- Check our IF status
  -- Note: Not referenced in the current APL, but saving for potential use later
  --Mage.IFTracker()

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies16ySplash, false)
    end

    -- Calculate remaining_winters_chill and icicles, as it's used in many lines
    if AoEON() and EnemiesCount16ySplash > 1 then
      RemainingWintersChill = CalculateWintersChill(Enemies16ySplash)
    else
      RemainingWintersChill = Target:DebuffStack(S.WintersChillDebuff)
    end
    Icicles = Player:BuffStackP(S.IciclesBuff)

    -- Calculate GCDMax
    GCDMax = Player:GCD() + 0.25
  end

  if Everyone.TargetIsValid() then
    -- arcane_intellect
    if S.ArcaneIntellect:IsCastable() and (Settings.Commons.AIDuringCombat or not Player:AffectingCombat()) and Everyone.GroupBuffMissing(S.ArcaneIntellect) then
      if Cast(S.ArcaneIntellect, Settings.CommonsOGCD.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect group_buff"; end
    end
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.CommonsDS.DisplayStyle.Interrupts, false); if ShouldReturn then return ShouldReturn; end
    -- Force Flurry in opener
    if S.Flurry:IsCastable() and S.Flurry:TimeSinceLastCast() > 5 and HL.CombatTime() < 5 then
      if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry opener"; end
    end
    -- call_action_list,name=cds
    -- Note: CDs() includes Trinkets/Items/Potion, so checking CDsON() within the function instead.
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    -- run_action_list,name=ff_aoe,if=talent.frostfire_bolt&active_enemies>=3
    if S.FrostfireBolt:IsAvailable() and EnemiesCount16ySplash >= 3 then
      local ShouldReturn = FFAoE(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for FFAoE()"; end
    end
    -- run_action_list,name=ss_aoe,if=active_enemies>=3
    if EnemiesCount16ySplash >= 3 then
      local ShouldReturn = SSAoE(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SSAoE()"; end
    end
    -- run_action_list,name=ff_cleave,if=talent.frostfire_bolt&active_enemies=2
    if S.FrostfireBolt:IsAvailable() and EnemiesCount16ySplash == 2 then
      local ShouldReturn = FFCleave(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for FFCleave()"; end
    end
    -- run_action_list,name=ss_cleave,if=active_enemies=2
    if EnemiesCount16ySplash == 2 then
      local ShouldReturn = SSCleave(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SSCleave()"; end
    end
    -- run_action_list,name=ff_st_boltspam,if=talent.frostfire_bolt&(talent.glacial_spike&talent.slick_ice&talent.cold_front&talent.deaths_chill&talent.deep_shatter)
    if S.FrostfireBolt:IsAvailable() and (S.GlacialSpike:IsAvailable() and S.SlickIce:IsAvailable() and S.ColdFront:IsAvailable() and S.DeathsChill:IsAvailable() and S.DeepShatter:IsAvailable()) then
      local ShouldReturn = FFSTBoltspam(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for FFSTBoltspam()"; end
    end
    -- run_action_list,name=ff_st,if=talent.frostfire_bolt
    if S.FrostfireBolt:IsAvailable() then
      local ShouldReturn = FFST(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for FFST()"; end
    end
    -- run_action_list,name=ss_st
    local ShouldReturn = SSST(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SSST()"; end
  end
end

local function Init()
  S.WintersChillDebuff:RegisterAuraTracking()

  HR.Print("Frost Mage rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(64, APL, Init)
