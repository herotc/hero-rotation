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
  I.BurstofKnowledge:ID(),
  I.HouseOfCards:ID(),
  I.ImperfectAscendancySerum:ID(),
  I.SpymastersWeb:ID(),
  I.TreacherousTransmitter:ID(),
  -- TWW S2 Prior Expansion Trinkets
  I.RatfangToxin:ID(),
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
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=treacherous_transmitter,if=fight_remains<32+20*equipped.spymasters_web|prev_off_gcd.icy_veins|(cooldown.icy_veins.remains<12|cooldown.icy_veins.remains<22&cooldown.shifting_power.remains<10)
    if I.TreacherousTransmitter:IsEquippedAndReady() and (BossFightRemains < 32 + 20 * num(I.SpymastersWeb:IsEquipped()) or Player:PrevOffGCDP(1, S.IcyVeins) or (S.IcyVeins:CooldownRemains() < 12 or S.IcyVeins:CooldownRemains() < 22 and S.ShiftingPower:CooldownRemains() < 10)) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter cds 2"; end
    end
    -- do_treacherous_transmitter_task,if=fight_remains<18|(buff.cryptic_instructions.remains<?buff.realigning_nexus_convergence_divergence.remains<?buff.errant_manaforge_emission.remains)<(action.shifting_power.execute_time+1*talent.ray_of_frost)
    -- TODO
    -- use_item,name=spymasters_web,if=fight_remains<20|buff.icy_veins.remains<19&(fight_remains<105|buff.spymasters_report.stack>=32)&(buff.icy_veins.remains>15|trinket.treacherous_transmitter.cooldown.remains>50)
    if I.SpymastersWeb:IsEquippedAndReady() and (BossFightRemains < 20 or Player:BuffRemains(S.IcyVeinsBuff) < 19 and (FightRemains < 105 or Player:BuffStack(S.SpymastersReportBuff) >= 32) and (Player:BuffRemains(S.IcyVeinsBuff) > 15 or I.TreacherousTransmitter:IsEquipped() and I.TreacherousTransmitter:CooldownRemains() > 50)) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web cds 4"; end
    end
    -- use_item,name=house_of_cards,if=buff.icy_veins.remains>9|fight_remains<20
    if I.HouseOfCards:IsEquippedAndReady() and (Player:BuffRemains(S.IcyVeinsBuff) > 9 or BossFightRemains < 20) then
      if Cast(I.HouseOfCards, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "house_of_cards cds 6"; end
    end
    -- use_item,name=imperfect_ascendancy_serum,if=buff.icy_veins.remains>15|fight_remains<20
    if I.ImperfectAscendancySerum:IsEquippedAndReady() and (Player:BuffRemains(S.IcyVeinsBuff) > 15 or BossFightRemains < 20) then
      if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum cds 8"; end
    end
    -- use_item,name=burst_of_knowledge,if=buff.icy_veins.remains>15|fight_remains<20
    if I.BurstofKnowledge:IsEquippedAndReady() and (Player:BuffRemains(S.IcyVeinsBuff) > 15 or BossFightRemains < 20) then
      if Cast(I.BurstofKnowledge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "burst_of_knowledge cds 10"; end
    end
    -- use_item,name=ratfang_toxin,if=time>10
    if I.RatfangToxin:IsEquippedAndReady() and (HL.CombatTime() > 10) then
      if Cast(I.RatfangToxin, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "ratfang_toxin cds 12"; end
    end
  end
  -- potion,if=fight_remains<35|buff.icy_veins.remains>15
  if Settings.Commons.Enabled.Potions and (BossFightRemains < 35 or Player:BuffRemains(S.IcyVeinsBuff) > 15) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 14"; end
    end
  end
  -- icy_veins,if=buff.icy_veins.remains<1.5&(talent.frostfire_bolt|active_enemies>=3)
  if CDsON() and S.IcyVeins:IsCastable() and (Player:BuffRemains(S.IcyVeinsBuff) < 1.5 and (S.FrostfireBolt:IsAvailable() or EnemiesCount16ySplash >= 3)) then
    if Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cds 16"; end
  end
  -- frozen_orb,if=time=0&active_enemies>=3
  -- Note: Can't get here at time=0.
  -- flurry,if=time=0&active_enemies<=2
  -- Note: Can't get here at time=0.
  -- icy_veins,if=buff.icy_veins.remains<1.5&talent.splinterstorm
  if CDsON() and S.IcyVeins:IsCastable() and (Player:BuffRemains(S.IcyVeinsBuff) < 1.5 and S.Splinterstorm:IsAvailable()) then
    if Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cds 18"; end
  end
  -- use_item,name=neural_synapse_enhancer,if=active_enemies<=2|prev_gcd.1.comet_storm|fight_remains<20
  if Settings.Commons.Enabled.Trinkets and I.NeuralSynapseEnhancer:IsEquippedAndReady() and (EnemiesCount8ySplash <= 2 or Player:PrevGCDP(1, S.CometStorm) or BossFightRemains < 20) then
    if Cast(I.NeuralSynapseEnhancer, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "neural_synapse_enhancer cds 20"; end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " cds 22"; end
      end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.power_infusion.down
  -- invoke_external_buff,name=blessing_of_summer,if=buff.blessing_of_summer.down
  -- Note: Not handling external buffs.
  if CDsON() then
    -- blood_fury
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 24"; end
    end
    -- berserking,if=buff.icy_veins.remains>9&buff.icy_veins.remains<15|fight_remains<15
    if S.Berserking:IsCastable() and (Player:BuffRemains(S.IcyVeinsBuff) > 9 and Player:BuffRemains(S.IcyVeinsBuff) < 15 or BossFightRemains < 15) then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 26"; end
    end
    -- fireblood
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 28"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 30"; end
    end
  end
end

local function Movement()
  -- any_blink,if=movement.distance>10
  -- Note: Not handling blink.
  -- ice_floes,if=buff.ice_floes.down
  if S.IceFloes:IsCastable() and (Player:BuffDown(S.IceFloes)) then
    if Cast(S.IceFloes, nil, Settings.Frost.DisplayStyle.Movement) then return "ice_floes movement 2"; end
  end
  -- ice_nova
  if S.IceNova:IsCastable() then
    if Cast(S.IceNova, nil, Settings.Frost.DisplayStyle.Movement, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova movement 4"; end
  end
  -- cone_of_cold,if=!talent.coldest_snap&active_enemies>=2
  if S.ConeofCold:IsReady() and (not S.ColdestSnap:IsAvailable() and EnemiesCount16ySplash >= 2) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold movement 6"; end
  end
  -- arcane_explosion,if=mana.pct>30&active_enemies>=2
  -- Note: If we're not in ArcaneExplosion range, just move to the next suggestion.
  if S.ArcaneExplosion:IsReady() and Target:IsInRange(10) and (Player:ManaPercentage() > 30 and EnemiesCount8ySplash >= 2) then
    if Cast(S.ArcaneExplosion, nil, Settings.Frost.DisplayStyle.Movement) then return "arcane_explosion movement 8"; end
  end
  -- fire_blast
  if S.FireBlast:IsReady() then
    if Cast(S.FireBlast, nil, Settings.Frost.DisplayStyle.Movement, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast movement 10"; end
  end
  -- ice_lance
  if S.IceLance:IsReady() then
    if Cast(S.IceLance, nil, Settings.Frost.DisplayStyle.Movement, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance movement 12"; end
  end
end

local function AoEFF()
  -- frostfire_bolt,if=talent.deaths_chill&buff.icy_veins.remains>9&(buff.deaths_chill.stack<9|buff.deaths_chill.stack=9&!action.frostfire_bolt.in_flight)
  if Bolt:IsReady() and (S.DeathsChill:IsAvailable() and Player:BuffRemains(S.IcyVeinsBuff) > 9 and (Player:BuffStack(S.DeathsChillBuff) < 9 or Player:BuffStack(S.DeathsChillBuff) == 9 and not Bolt:InFlight())) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt aoe_ff 2"; end
  end
  -- cone_of_cold,if=talent.coldest_snap&prev_gcd.1.comet_storm
  if S.ConeofCold:IsCastable() and (S.ColdestSnap:IsAvailable() and Player:PrevGCDP(1, S.CometStorm)) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold aoe_ff 4"; end
  end
  -- freeze,if=freezable&(prev_gcd.1.glacial_spike|prev_gcd.1.comet_storm&time-action.cone_of_cold.last_used>8)
  if Pet:IsActive() and S.Freeze:IsReady() and (Freezable() and (Player:PrevGCDP(1, S.GlacialSpike) or Player:PrevGCDP(1, S.CometStorm) and S.ConeofCold:TimeSinceLastCast() > 8)) then
    if Cast(S.Freeze, nil, nil, not Target:IsSpellInRange(S.Freeze)) then return "freeze aoe_ff 6"; end
  end
  -- ice_nova,if=freezable&!prev_off_gcd.freeze&(prev_gcd.1.glacial_spike&remaining_winters_chill=0&debuff.winters_chill.down|prev_gcd.1.comet_storm&time-action.cone_of_cold.last_used>8)
  if S.IceNova:IsCastable() and (Freezable() and not Player:PrevOffGCDP(1, S.Freeze) and (Player:PrevGCDP(1, S.GlacialSpike) and RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) or Player:PrevGCDP(1, S.CometStorm) and S.ConeofCold:TimeSinceLastCast() > 8)) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe_ff 8"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb aoe_ff 10"; end
  end
  -- ice_lance,if=buff.excess_fire.stack=2&action.comet_storm.cooldown_react
  if S.IceLance:IsReady() and (Player:BuffStack(S.ExcessFireBuff) == 2 and S.CometStorm:CooldownUp()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe_ff 12"; end
  end
  -- blizzard,if=talent.ice_caller|talent.freezing_rain
  if S.Blizzard:IsCastable() and (S.IceCaller:IsAvailable() or S.FreezingRain:IsAvailable()) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard aoe_ff 14"; end
  end
  -- comet_storm,if=cooldown.cone_of_cold.remains>10|cooldown.cone_of_cold.ready
  if S.CometStorm:IsCastable() and (S.ConeofCold:CooldownRemains() > 10 or S.ConeofCold:CooldownUp()) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe_ff 16"; end
  end
  -- ray_of_frost,if=talent.splintering_ray&remaining_winters_chill
  if S.RayofFrost:IsCastable() and (S.SplinteringRay:IsAvailable() and RemainingWintersChill > 0) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost aoe_ff 18"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike aoe_ff 20"; end
  end
  -- flurry,if=cooldown_react&buff.excess_fire.up&buff.excess_frost.up
  if S.Flurry:IsCastable() and (Player:BuffUp(S.ExcessFireBuff) and Player:BuffUp(S.ExcessFrostBuff)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe_ff 22"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe_ff 24"; end
  end
  -- frostfire_bolt,if=buff.frostfire_empowerment.react&!buff.excess_fire.up
  if Bolt:IsReady() and (Player:BuffUp(S.FrostfireEmpowermentBuff) and Player:BuffDown(S.ExcessFireBuff)) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt aoe_ff 26"; end
  end
  -- shifting_power,if=cooldown.icy_veins.remains>10&cooldown.frozen_orb.remains>10&(!talent.comet_storm|cooldown.comet_storm.remains>10)
  if CDsON() and S.ShiftingPower:IsCastable() and (S.IcyVeins:CooldownRemains() > 10 and S.FrozenOrb:CooldownRemains() > 10 and (not S.CometStorm:IsAvailable() or S.CometStorm:CooldownRemains() > 10)) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power aoe_ff 28"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) or RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe_ff 30"; end
  end
  -- frostfire_bolt
  if Bolt:IsReady() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt aoe_ff 32"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function AoESS()
  -- cone_of_cold,if=talent.coldest_snap&!action.frozen_orb.cooldown_react&(prev_gcd.1.comet_storm|prev_gcd.1.frozen_orb&cooldown.comet_storm.remains>5)&(!talent.deaths_chill|buff.icy_veins.remains<9|buff.deaths_chill.stack>=15)
  if S.ConeofCold:IsReady() and (S.ColdestSnap:IsAvailable() and S.FrozenOrb:CooldownDown() and (Player:PrevGCDP(1, S.CometStorm) or Player:PrevGCDP(1, S.FrozenOrb) and S.CometStorm:CooldownRemains() > 5) and (not S.DeathsChill:IsAvailable() or Player:BuffRemains(S.IcyVeinsBuff) < 9 or Player:BuffStack(S.DeathsChillBuff) >= 15)) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold aoe_ss 2"; end
  end
  -- freeze,if=freezable&(prev_gcd.1.glacial_spike|!talent.glacial_spike)
  if Pet:IsActive() and S.Freeze:IsReady() and (Freezable() and (Player:PrevGCDP(1, S.GlacialSpike) or not S.GlacialSpike:IsAvailable())) then
    if Cast(S.Freeze, nil, nil, not Target:IsSpellInRange(S.Freeze)) then return "freeze aoe_ss 4"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&prev_gcd.1.glacial_spike
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe_ss 6"; end
  end
  -- ice_nova,if=freezable&!prev_off_gcd.freeze&prev_gcd.1.glacial_spike&remaining_winters_chill=0&debuff.winters_chill.down
  if S.IceNova:IsCastable() and (Freezable() and not Player:PrevOffGCDP(1, S.Freeze) and Player:PrevGCDP(1, S.GlacialSpike) and RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff)) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe_ss 8"; end
  end
  -- ice_nova,if=talent.unerring_proficiency&time-action.cone_of_cold.last_used<10&time-action.cone_of_cold.last_used>7
  if S.IceNova:IsCastable() and (S.UnerringProficiency:IsAvailable() and S.ConeofCold:TimeSinceLastCast() < 10 and S.ConeofCold:TimeSinceLastCast() > 7) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe_ss 10"; end
  end
  -- frozen_orb,if=cooldown_react
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb aoe_ss 12"; end
  end
  -- blizzard,if=talent.ice_caller|talent.freezing_rain
  if S.Blizzard:IsCastable() and (S.IceCaller:IsAvailable() or S.FreezingRain:IsAvailable()) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard aoe_ss 14"; end
  end
  -- frostbolt,if=talent.deaths_chill&buff.icy_veins.remains>9&(buff.deaths_chill.stack<12|buff.deaths_chill.stack=12&!action.frostbolt.in_flight)
  if Bolt:IsCastable() and (S.DeathsChill:IsAvailable() and Player:BuffRemains(S.IcyVeinsBuff) > 9 and (Player:BuffStack(S.DeathsChillBuff) < 12 or Player:BuffStack(S.DeathsChillBuff) == 12 and not Bolt:InFlight())) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt aoe_ss 16"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastable() then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe_ss 18"; end
  end
  -- ray_of_frost,if=talent.splintering_ray&remaining_winters_chill&buff.icy_veins.down
  if S.RayofFrost:IsCastable() and (S.SplinteringRay:IsAvailable() and RemainingWintersChill > 0 and Player:BuffDown(S.IcyVeinsBuff)) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost aoe_ss 20"; end
  end
  -- glacial_spike,if=buff.icicles.react=5&(action.flurry.cooldown_react|remaining_winters_chill|freezable&cooldown.ice_nova.ready)
  if S.GlacialSpike:IsReady() and (Icicles == 5 and (S.Flurry:CooldownUp() or RemainingWintersChill > 0 or Freezable() and S.IceNova:CooldownUp())) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike aoe_ss 22"; end
  end
  -- shifting_power,if=cooldown.icy_veins.remains>10&(fight_remains+15>cooldown.icy_veins.remains)
  if CDsON() and S.ShiftingPower:IsCastable() and (S.IcyVeins:CooldownRemains() > 10 and (FightRemains + 15 > S.IcyVeins:CooldownRemains())) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power aoe_ss 24"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) or RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe_ss 26"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe_ss 28"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt aoe_ss 30"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function CleaveFF()
  -- frostfire_bolt,if=talent.deaths_chill&buff.icy_veins.remains>9&(buff.deaths_chill.stack<4|buff.deaths_chill.stack=4&!action.frostfire_bolt.in_flight)
  if Bolt:IsCastable() and (S.DeathsChill:IsAvailable() and Player:BuffRemains(S.IcyVeinsBuff) > 9 and (Player:BuffStack(S.DeathsChillBuff) < 4 or Player:BuffStack(S.DeathsChillBuff) == 4 and not Bolt:InFlight())) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt cleave_ff 2"; end
  end
  -- freeze,if=freezable&prev_gcd.1.glacial_spike
  if Pet:IsActive() and S.Freeze:IsCastable() and (Freezable() and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.Freeze, nil, nil, not Target:IsSpellInRange(S.Freeze)) then return "freeze cleave_ff 4"; end
  end
  -- ice_nova,if=freezable&prev_gcd.1.glacial_spike&remaining_winters_chill=0&debuff.winters_chill.down&!prev_off_gcd.freeze
  if S.IceNova:IsCastable() and (Freezable() and Player:PrevGCDP(1, S.GlacialSpike) and RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and not Player:PrevOffGCDP(1, S.Freeze)) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova cleave_ff 6"; end
  end
  -- flurry,target_if=min:debuff.winters_chill.stack,if=cooldown_react&prev_gcd.1.glacial_spike&!prev_off_gcd.freeze
  if S.Flurry:IsCastable() and (Player:PrevGCDP(1, S.GlacialSpike) and not Player:PrevOffGCDP(1, S.Freeze)) then
    if Everyone.CastTargetIf(S.Flurry, Enemies16ySplash, "min", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.Flurry), Settings.Frost.GCDasOffGCD.Flurry) then return "flurry cleave_ff 8"; end
  end
  -- flurry,if=cooldown_react&(buff.icicles.react<5|!talent.glacial_spike)&remaining_winters_chill=0&debuff.winters_chill.down&(prev_gcd.1.frostfire_bolt|prev_gcd.1.comet_storm)
  if S.Flurry:IsCastable() and ((Icicles < 5 or not S.GlacialSpike:IsAvailable()) and RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and (Player:PrevGCDP(1, Bolt) or Player:PrevGCDP(1, S.CometStorm))) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry cleave_ff 10"; end
  end
  -- flurry,if=cooldown_react&(buff.icicles.react<5|!talent.glacial_spike)&buff.excess_fire.up&buff.excess_frost.up
  if S.Flurry:IsCastable() and ((Icicles < 5 or not S.GlacialSpike:IsAvailable()) and Player:BuffUp(S.ExcessFireBuff) and Player:BuffUp(S.ExcessFrostBuff)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry cleave_ff 12"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastable() then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm cleave_ff 14"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb cleave_ff 16"; end
  end
  -- blizzard,if=buff.freezing_rain.up&talent.ice_caller
  if S.Blizzard:IsCastable() and (Player:BuffUp(S.FreezingRainBuff) and S.IceCaller:IsAvailable()) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard cleave_ff 18"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike cleave_ff 20"; end
  end
  -- ray_of_frost,target_if=max:debuff.winters_chill.stack,if=remaining_winters_chill=1
  if S.RayofFrost:IsCastable() and (RemainingWintersChill == 1) then
    if Everyone.CastTargetIf(S.RayofFrost, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.RayofFrost), Settings.Frost.GCDasOffGCD.RayOfFrost) then return "ray_of_frost cleave_ff 22"; end
  end
  -- frostfire_bolt,if=buff.frostfire_empowerment.react&!buff.excess_fire.up
  if Bolt:IsReady() and (Player:BuffUp(S.FrostfireEmpowermentBuff) and Player:BuffDown(S.ExcessFireBuff)) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt cleave_ff 24"; end
  end
  -- shifting_power,if=cooldown.icy_veins.remains>10&cooldown.frozen_orb.remains>10&(!talent.comet_storm|cooldown.comet_storm.remains>10)&(!talent.ray_of_frost|cooldown.ray_of_frost.remains>10)
  if CDsON() and S.ShiftingPower:IsCastable() and (S.IcyVeins:CooldownRemains() > 10 and S.FrozenOrb:CooldownRemains() > 10 and (not S.CometStorm:IsAvailable() or S.CometStorm:CooldownRemains() > 10) and (not S.RayofFrost:IsAvailable() or S.RayofFrost:CooldownRemains() > 10)) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power cleave_ff 26"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=buff.fingers_of_frost.react|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) or RemainingWintersChill > 0) then
    if Everyone.CastTargetIf(S.IceLance, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance cleave_ff 28"; end
  end
  -- frostfire_bolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt cleave_ff 30"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function CleaveSS()
  -- flurry,target_if=min:debuff.winters_chill.stack,if=cooldown_react&prev_gcd.1.glacial_spike&!prev_off_gcd.freeze
  if S.Flurry:IsCastable() and (Player:PrevGCDP(1, S.GlacialSpike) and not Player:PrevOffGCDP(1, S.Freeze)) then
    if Everyone.CastTargetIf(S.Flurry, Enemies16ySplash, "min", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.Flurry), Settings.Frost.GCDasOffGCD.Flurry) then return "flurry cleave_ss 2"; end
  end
  -- freeze,if=freezable&prev_gcd.1.glacial_spike
  if Pet:IsActive() and S.Freeze:IsReady() and (Freezable() and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.Freeze, nil, nil, not Target:IsSpellInRange(S.Freeze)) then return "freeze cleave_ss 4"; end
  end
  -- ice_nova,if=freezable&!prev_off_gcd.freeze&remaining_winters_chill=0&debuff.winters_chill.down&prev_gcd.1.glacial_spike
  if S.IceNova:IsCastable() and (Freezable() and not Player:PrevOffGCDP(1, S.Freeze) and RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova cleave_ss 6"; end
  end
  -- flurry,if=cooldown_react&debuff.winters_chill.down&remaining_winters_chill=0&prev_gcd.1.frostbolt
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and RemainingWintersChill == 0 and Player:PrevGCDP(1, S.Frostbolt)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry cleave_ss 8"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react=2
  if S.IceLance:IsReady() and (Player:BuffStack(S.FingersofFrostBuff) == 2) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance cleave_ss 10"; end
  end
  -- comet_storm,if=remaining_winters_chill&buff.icy_veins.down
  if S.CometStorm:IsCastable() and (RemainingWintersChill > 0 and Player:BuffDown(S.IcyVeinsBuff)) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm cleave_ss 12"; end
  end
  -- frozen_orb,if=cooldown_react&(cooldown.icy_veins.remains>30|buff.icy_veins.react)
  if S.FrozenOrb:IsCastable() and (S.IcyVeins:CooldownRemains() > 30 or Player:BuffUp(S.IcyVeinsBuff)) then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb cleave_ss 14"; end
  end
  -- ray_of_frost,target_if=max:debuff.winters_chill.stack,if=prev_gcd.1.flurry&buff.icy_veins.down
  if S.RayofFrost:IsCastable() and (Player:PrevGCDP(1, S.Flurry) and Player:BuffDown(S.IcyVeinsBuff)) then
    if Everyone.CastTargetIf(S.RayofFrost, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.RayofFrost), Settings.Frost.GCDasOffGCD.RayOfFrost) then return "ray_of_frost cleave_ss 16"; end
  end
  -- glacial_spike,if=buff.icicles.react=5&(action.flurry.cooldown_react|remaining_winters_chill|freezable&cooldown.ice_nova.ready)
  if S.GlacialSpike:IsReady() and (Icicles == 5 and (S.Flurry:CooldownUp() or RemainingWintersChill > 0 or Freezable() and S.IceNova:CooldownUp())) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike cleave_ss 18"; end
  end
  -- shifting_power,if=cooldown.icy_veins.remains>10&!action.flurry.cooldown_react&(fight_remains+15>cooldown.icy_veins.remains)
  if CDsON() and S.ShiftingPower:IsCastable() and (S.IcyVeins:CooldownRemains() > 10 and S.Flurry:CooldownDown() and (FightRemains + 15 > S.IcyVeins:CooldownRemains())) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power cleave_ss 20"; end
  end
  -- frostbolt,if=talent.deaths_chill&buff.icy_veins.remains>9&(buff.deaths_chill.stack<6|buff.deaths_chill.stack=6&!action.frostbolt.in_flight)
  if Bolt:IsCastable() and (S.DeathsChill:IsAvailable() and Player:BuffRemains(S.IcyVeinsBuff) > 9 and (Player:BuffStack(S.DeathsChillBuff) < 6 or Player:BuffStack(S.DeathsChillBuff) == 6 and not Bolt:InFlight())) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt cleave_ss 22"; end
  end
  -- blizzard,if=talent.freezing_rain&talent.ice_caller
  if S.Blizzard:IsCastable() and (S.FreezingRain:IsAvailable() and S.IceCaller:IsAvailable()) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard cleave_ss 24"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=buff.fingers_of_frost.react|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) or RemainingWintersChill > 0) then
    if Everyone.CastTargetIf(S.IceLance, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance cleave_ss 26"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt cleave_ss 28"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function STFF()
  -- flurry,if=cooldown_react&(buff.icicles.react<5|!talent.glacial_spike)&remaining_winters_chill=0&debuff.winters_chill.down&(prev_gcd.1.glacial_spike|prev_gcd.1.frostfire_bolt|prev_gcd.1.comet_storm)
  if S.Flurry:IsCastable() and ((Icicles < 5 or not S.GlacialSpike:IsAvailable()) and RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and (Player:PrevGCDP(1, S.GlacialSpike) or Player:PrevGCDP(1, Bolt) or Player:PrevGCDP(1, S.CometStorm))) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry st_ff 2"; end
  end
  -- flurry,if=cooldown_react&(buff.icicles.react<5|!talent.glacial_spike)&buff.excess_fire.up&buff.excess_frost.up
  if S.Flurry:IsCastable() and ((Icicles < 5 or not S.GlacialSpike:IsAvailable()) and Player:BuffUp(S.ExcessFireBuff) and Player:BuffUp(S.ExcessFrostBuff)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry st_ff 4"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastable() then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm st_ff 6"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike st_ff 8"; end
  end
  -- ray_of_frost,if=remaining_winters_chill=1
  if S.RayofFrost:IsCastable() and (RemainingWintersChill == 1) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost st_ff 10"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb st_ff 12"; end
  end
  -- shifting_power,if=cooldown.icy_veins.remains>10&cooldown.frozen_orb.remains>10&(!talent.comet_storm|cooldown.comet_storm.remains>10)&(!talent.ray_of_frost|cooldown.ray_of_frost.remains>10)
  if CDsON() and S.ShiftingPower:IsCastable() and (S.IcyVeins:CooldownRemains() > 10 and S.FrozenOrb:CooldownRemains() > 10 and (not S.CometStorm:IsAvailable() or S.CometStorm:CooldownRemains() > 10) and (not S.RayofFrost:IsAvailable() or S.RayofFrost:CooldownRemains() > 10)) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power st_ff 14"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) or RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance st_ff 16"; end
  end
  -- frostfire_bolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostfire_bolt st_ff 18"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function STSS()
  -- flurry,if=cooldown_react&debuff.winters_chill.down&remaining_winters_chill=0&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt)
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and RemainingWintersChill == 0 and (Player:PrevGCDP(1, S.GlacialSpike) or Player:PrevGCDP(1, S.Frostbolt))) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry st_ss 2"; end
  end
  -- comet_storm,if=remaining_winters_chill&buff.icy_veins.down
  if S.CometStorm:IsCastable() and (RemainingWintersChill > 0 and Player:BuffDown(S.IcyVeinsBuff)) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm st_ss 4"; end
  end
  -- frozen_orb,if=cooldown_react&(cooldown.icy_veins.remains>30|buff.icy_veins.react)
  if S.FrozenOrb:IsCastable() and (S.IcyVeins:CooldownRemains() > 30 or Player:BuffUp(S.IcyVeinsBuff)) then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb st_ss 6"; end
  end
  -- ray_of_frost,if=prev_gcd.1.flurry
  if S.RayofFrost:IsCastable() and (Player:PrevGCDP(1, S.Flurry)) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost st_ss 8"; end
  end
  -- glacial_spike,if=buff.icicles.react=5&(action.flurry.cooldown_react|remaining_winters_chill)
  if S.GlacialSpike:IsReady() and (Icicles == 5 and (S.Flurry:CooldownUp() or RemainingWintersChill > 0)) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike st_ss 10"; end
  end
  -- shifting_power,if=cooldown.icy_veins.remains>10&!action.flurry.cooldown_react&(fight_remains+15>cooldown.icy_veins.remains)
  if CDsON() and S.ShiftingPower:IsCastable() and (S.IcyVeins:CooldownRemains() > 10 and S.Flurry:CooldownDown() and (FightRemains + 15 > S.IcyVeins:CooldownRemains())) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power st_ss 12"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) or RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance st_ss 14"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt st_ss 16"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
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
    -- run_action_list,name=aoe_ff,if=talent.frostfire_bolt&active_enemies>=3
    if AoEON() and (S.FrostfireBolt:IsAvailable() and EnemiesCount16ySplash >= 3) then
      local ShouldReturn = AoEFF(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for AoeFF()"; end
    end
    -- run_action_list,name=aoe_ss,if=active_enemies>=3
    if AoEON() and (EnemiesCount16ySplash >= 3) then
      local ShouldReturn = AoESS(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for AoeSS()"; end
    end
    -- run_action_list,name=cleave_ff,if=talent.frostfire_bolt&active_enemies=2
    if AoEON() and (S.FrostfireBolt:IsAvailable() and EnemiesCount16ySplash == 2) then
      local ShouldReturn = CleaveFF(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for CleaveFF()"; end
    end
    -- run_action_list,name=cleave_ss,if=active_enemies=2
    if AoEON() and (EnemiesCount16ySplash == 2) then
      local ShouldReturn = CleaveSS(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for CleaveSS()"; end
    end
    -- run_action_list,name=st_ff,if=talent.frostfire_bolt
    if S.FrostfireBolt:IsAvailable() then
      local ShouldReturn = STFF(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for STFF()"; end
    end
    -- run_action_list,name=st_ss
    local ShouldReturn = STSS(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for STSS()"; end
  end
end

local function Init()
  S.WintersChillDebuff:RegisterAuraTracking()

  HR.Print("Frost Mage rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(64, APL, Init)
