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
local mathmax        = math.max

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Frost
local I = Item.Mage.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- TWW Trinkets
  I.ImperfectAscendancySerum:ID(),
  I.SpymastersWeb:ID(),
  -- DF Trinkets
  I.BelorrelostheSuncaller:ID(),
  -- DF Other Items
  I.Dreambinder:ID(),
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
local EnemiesCount8ySplash, EnemiesCount16ySplash --Enemies arround target
local Enemies16ySplash
local RemainingWintersChill = 0
local Icicles = 0
local PlayerMaxLevel = 70 -- Check Enum for a max player level value
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax
local Bolt = S.FrostfireBolt:IsAvailable() and S.FrostfireBolt or S.Frostbolt

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
  S.Splinterstorm:RegisterInFlight()
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
S.Splinterstorm:RegisterInFlight()

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
  RemainingWintersChill = 0
end, "PLAYER_REGEN_ENABLED")

--- ===== Helper Functions =====
local function Freezable(Tar)
  if Tar == nil then Tar = Target end
  return (not Tar:IsInBossList() or Tar:Level() < PlayerMaxLevel + 3)
end

local function FrozenRemains()
  return mathmax(Player:BuffRemains(S.FingersofFrostBuff), Target:DebuffRemains(S.WintersChillDebuff), Target:DebuffRemains(S.Frostbite), Target:DebuffRemains(S.Freeze), Target:DebuffRemains(S.FrostNova))
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
  -- target_if=min:debuff.winters_chill.stack
  return (TargetUnit:DebuffStack(S.WintersChillDebuff))
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfFlurrySSCleave(TargetUnit)
  -- if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&(prev_gcd.1.frostbolt|prev_gcd.1.glacial_spike)
  -- Note: All but debuff checked prior to CastTargetIf.
  return TargetUnit:DebuffDown(S.WintersChillDebuff)
end

local function EvaluateTargetIfIceLanceSSCleave(TargetUnit)
  -- if=buff.icy_veins.up&debuff.winters_chill.stack=2
  -- Note: Buff check handled prior to CastTargetIf.
  return TargetUnit:DebuffStack(S.WintersChillDebuff) == 2
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Everyone.GroupBuffMissing(S.ArcaneIntellect) then
    if Cast(S.ArcaneIntellect, Settings.CommonsOGCD.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect precombat 2"; end
  end
  -- snapshot_stats
  -- blizzard,if=active_enemies>=2&talent.ice_caller&!talent.fractured_frost|active_enemies>=3
  -- Note: Can't check active_enemies in Precombat
  -- frostbolt,if=active_enemies<=2
  if Bolt:IsCastable() and not Player:IsCasting(Bolt) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt precombat 4"; end
  end
end

local function Cooldowns()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=imperfect_ascendancy_serum,if=buff.icy_veins.remains>19|fight_remains<25
    if I.ImperfectAscendancySerum:IsEquippedAndReady() and (Player:BuffRemains(S.IcyVeinsBuff) > 19 or BossFightRemains < 25) then
      if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum cd 2"; end
    end
    -- use_item,name=spymasters_web,if=(buff.icy_veins.remains>19&fight_remains<100)|fight_remains<25
    if I.SpymastersWeb:IsEquippedAndReady() and ((Player:BuffRemains(S.IcyVeinsBuff) > 19 and BossFightRemains < 100) or BossFightRemains < 25) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web cd 4"; end
    end
  end
  -- potion,if=prev_off_gcd.icy_veins|fight_remains<60
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.IcyVeinsBuff) or FightRemains < 60) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cd 6"; end
    end
  end
  -- use_item,name=dreambinder_loom_of_the_great_cycle,if=(equipped.nymues_unraveling_spindle&prev_gcd.1.nymues_unraveling_spindle)|fight_remains>2
  if Settings.Commons.Enabled.Items and I.Dreambinder:IsEquippedAndReady() and ((I.NymuesUnravelingSpindle:IsEquipped() and Player:PrevGCDP(1, I.NymuesUnravelingSpindle)) or FightRemains > 2) then
    if Cast(I.Dreambinder, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(45)) then return "dreambinder_loom_of_the_great_cycle cd 8"; end
  end
  -- use_item,name=belorrelos_the_suncaller,if=time>5&!prev_gcd.1.flurry
  if Settings.Commons.Enabled.Trinkets and I.BelorrelostheSuncaller:IsEquippedAndReady() and (HL.CombatTime() > 5 and not Player:PrevGCDP(1, S.Flurry)) then
    if Cast(I.BelorrelostheSuncaller, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller cd 10"; end
  end
  -- flurry,if=time=0&active_enemies<=2
  -- Note: Can't get target count at time=0
  -- icy_veins
  if S.IcyVeins:IsCastable() then
    if Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cd 12"; end
  end
  -- use_items
  if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " cd 14"; end
      end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.power_infusion.down
  -- invoke_external_buff,name=blessing_of_summer,if=buff.blessing_of_summer.down
  -- Note: Not handling external buffs.
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cd 16"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cd 18"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cd 20"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cd 22"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cd 24"; end
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

local function Aoe()
  -- cone_of_cold,if=talent.coldest_snap&(prev_gcd.1.comet_storm|prev_gcd.1.frozen_orb&!talent.comet_storm)
  if S.ConeofCold:IsCastable() and (S.ColdestSnap:IsAvailable() and (Player:PrevGCDP(1, S.CometStorm) or Player:PrevGCDP(1, S.FrozenOrb) and not S.CometStorm:IsAvailable())) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold aoe 2"; end
  end
  -- frozen_orb,if=(!prev_gcd.1.cone_of_cold|!talent.isothermic_core)&(!prev_gcd.1.glacial_spike|!freezable)
  if S.FrozenOrb:IsCastable() and ((not Player:PrevGCDP(1, S.ConeofCold) or not S.IsothermicCore:IsAvailable()) and (not Player:PrevGCDP(1, S.GlacialSpike) or not Freezable())) then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb aoe 4"; end
  end
  -- blizzard,if=!prev_gcd.1.glacial_spike|!freezable
  if S.Blizzard:IsCastable() and (not Player:PrevGCDP(1, S.GlacialSpike) or not Freezable()) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard aoe 6"; end
  end
  -- frostbolt,if=buff.icy_veins.up&(buff.deaths_chill.stack<9|buff.deaths_chill.stack=9&!action.frostbolt.in_flight)&buff.icy_veins.remains>8&talent.deaths_chill
  if Bolt:IsReady() and (Player:BuffUp(S.IcyVeinsBuff) and (Player:BuffStack(S.DeathsChillBuff) < 9 or Player:BuffStack(S.DeathsChillBuff) == 0 and not Bolt:InFlight()) and Player:BuffRemains(S.IcyVeinsBuff) > 8 and S.DeathsChill:IsAvailable()) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt aoe 8"; end
  end
  -- comet_storm,if=!prev_gcd.1.glacial_spike&(!talent.coldest_snap|cooldown.cone_of_cold.ready&cooldown.frozen_orb.remains>25|(cooldown.cone_of_cold.remains>10&talent.frostfire_bolt|cooldown.cone_of_cold.remains>20&!talent.frostfire_bolt))
  if S.CometStorm:IsCastable() and (not Player:PrevGCDP(1, S.GlacialSpike) and (not S.ColdestSnap:IsAvailable() or S.ConeofCold:CooldownUp() and S.FrozenOrb:CooldownRemains() > 25 or (S.ConeofCold:CooldownRemains() > 10 and S.FrostfireBolt:IsAvailable() or S.ConeofCold:CooldownRemains() > 20 and not S.FrostfireBolt:IsAvailable()))) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe 10"; end
  end
  -- freeze,if=freezable&debuff.frozen.down&(!talent.glacial_spike|prev_gcd.1.glacial_spike)
  if Pet:IsActive() and S.Freeze:IsReady() and (Freezable() and FrozenRemains() == 0 and (not S.GlacialSpike:IsAvailable() or Player:PrevGCDP(1, S.GlacialSpike))) then
    if Cast(S.Freeze, nil, nil, not Target:IsSpellInRange(S.Freeze)) then return "freeze aoe 12"; end
  end
  -- ice_nova,if=freezable&!prev_off_gcd.freeze&(prev_gcd.1.glacial_spike)
  if S.IceNova:IsCastable() and (Freezable() and not Player:PrevOffGCDP(1, S.Freeze) and Player:PrevGCDP(1, S.GlacialSpike)) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 14"; end
  end
  -- frost_nova,if=freezable&!prev_off_gcd.freeze&(prev_gcd.1.glacial_spike&!remaining_winters_chill)
  if S.FrostNova:IsCastable() and (Freezable() and not Player:PrevOffGCDP(1, S.Freeze) and (Player:PrevGCDP(1, S.GlacialSpike) and RemainingWintersChill == 0)) then
    if Cast(S.FrostNova, nil, nil, not Target:IsInRange(12)) then return "frost_nova aoe 16"; end
  end
  -- shifting_power,if=cooldown.comet_storm.remains>10
  if CDsON() and S.ShiftingPower:IsCastable() and (S.CometStorm:CooldownRemains() > 10) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power aoe 18"; end
  end
  -- frostbolt,if=buff.frostfire_empowerment.react&!buff.excess_frost.react&!buff.excess_fire.react
  if Bolt:IsCastable() and (Player:BuffUp(S.FrostfireEmpowermentBuff) and Player:BuffDown(S.ExcessFrostBuff) and Player:BuffDown(S.ExcessFireBuff)) then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt aoe 20"; end
  end
  -- flurry,if=cooldown_react&!remaining_winters_chill&(buff.brain_freeze.react&!talent.excess_frost|buff.excess_frost.react)
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and (Player:BuffUp(S.BrainFreezeBuff) and not S.ExcessFrost:IsAvailable() or Player:BuffUp(S.ExcessFrostBuff))) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 22"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) or FrozenRemains() > S.IceLance:TravelTime() or bool(RemainingWintersChill)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 24"; end
  end
  -- flurry,if=cooldown_react&!remaining_winters_chill
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 26"; end
  end
  -- ice_nova,if=active_enemies>=4&(!talent.glacial_spike|!freezable)&!talent.frostfire_bolt
  if S.IceNova:IsCastable() and (EnemiesCount8ySplash >= 4 and (not S.GlacialSpike:IsAvailable() or not Freezable()) and not S.FrostfireBolt:IsAvailable()) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 28"; end
  end
  -- cone_of_cold,if=!talent.coldest_snap&active_enemies>=7
  if S.ConeofCold:IsReady() and (not S.ColdestSnap:IsAvailable() and EnemiesCount16ySplash >= 7) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold aoe 30"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt aoe 36"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function SSCleave()
  -- flurry,target_if=min:debuff.winters_chill.stack,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&(prev_gcd.1.frostbolt|prev_gcd.1.glacial_spike)
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and (Player:PrevGCDP(1, S.Frostbolt) or Player:PrevGCDP(1, S.GlacialSpike))) then
    if Everyone.CastTargetIf(S.Flurry, Enemies16ySplash, "min", EvaluateTargetIfFilterWCStacks, EvaluateTargetIfFlurrySSCleave, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_cleave 2"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=buff.icy_veins.up&debuff.winters_chill.stack=2
  if S.IceLance:IsReady() and (Player:BuffUp(S.IcyVeinsBuff)) then
    if Everyone.CastTargetIf(S.IceLance, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, EvaluateTargetIfIceLanceSSCleave, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_cleave 4"; end
  end
  -- ray_of_frost,if=buff.icy_veins.down&buff.freezing_winds.down&remaining_winters_chill=1
  if S.RayofFrost:IsCastable() and (Player:BuffDown(S.IcyVeinsBuff) and Player:BuffDown(S.FreezingWindsBuff) and RemainingWintersChill == 1) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost ss_cleave 6"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb ss_cleave 8"; end
  end
  -- shifting_power
  if CDsON() and S.ShiftingPower:IsCastable() then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ss_cleave 10"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=remaining_winters_chill|buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (RemainingWintersChill > 0 or Player:BuffUp(S.FingersofFrostBuff)) then
    if Everyone.CastTargetIf(S.IceLance, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_cleave 12"; end
  end
  -- comet_storm,if=prev_gcd.1.flurry|prev_gcd.1.cone_of_cold|action.splinterstorm.in_flight
  -- TODO: Figure out a way to handle action.splinterstorm.in_flight
  if S.CometStorm:IsCastable() and (Player:PrevGCDP(1, S.Flurry) or Player:PrevGCDP(1, S.ConeofCold)) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm ss_cleave 14"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike ss_cleave 16"; end
  end
  -- flurry,target_if=min:debuff.winters_chill.stack,if=cooldown_react&buff.icy_veins.up
  if S.Flurry:IsCastable() and (Player:BuffUp(S.IcyVeinsBuff)) then
    if Everyone.CastTargetIf(S.Flurry, Enemies16ySplash, "min", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_cleave 18"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt ss_cleave 20"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function Cleave()
  -- comet_storm,if=prev_gcd.1.flurry|prev_gcd.1.cone_of_cold
  if S.CometStorm:IsCastable() and (Player:PrevGCDP(1, S.Flurry) or Player:PrevGCDP(1, S.ConeofCold)) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm cleave 2"; end
  end
  -- flurry,target_if=min:debuff.winters_chill.stack,if=cooldown_react&(((prev_gcd.1.frostbolt|prev_gcd.1.frostfire_bolt)&buff.icicles.react>=3)|prev_gcd.1.glacial_spike|(buff.icicles.react>=3&buff.icicles.react<5&charges_fractional=2))
  if S.Flurry:IsCastable() and ((Player:PrevGCDP(1, Bolt) and Icicles >= 3) or Player:PrevGCDP(1, S.GlacialSpike) or (Icicles >= 3 and Icicles < 5 and S.Flurry:ChargesFractional() == 2)) then
    if Everyone.CastTargetIf(S.Flurry, Enemies16ySplash, "min", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.Flurry), Settings.Frost.GCDasOffGCD.Flurry) then return "flurry cleave 4"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=talent.glacial_spike&debuff.winters_chill.down&buff.icicles.react=4&buff.fingers_of_frost.react
  -- Note: Competing target_if and debuff.winters_chill.down mean this should only happen if no targets have WC. Using AuraActiveCount() instead.
  if S.IceLance:IsReady() and (S.GlacialSpike:IsAvailable() and S.WintersChillDebuff:AuraActiveCount() == 0 and Icicles == 4 and Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance cleave 6"; end
  end
  -- ray_of_frost,target_if=max:debuff.winters_chill.stack,if=remaining_winters_chill=1
  if S.RayofFrost:IsCastable() and (RemainingWintersChill == 1) then
    if Everyone.CastTargetIf(S.RayofFrost, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.RayofFrost), Settings.Frost.GCDasOffGCD.RayOfFrost) then return "ray_of_frost cleave 8"; end
  end
  -- glacial_spike,if=buff.icicles.react=5&(action.flurry.cooldown_react|remaining_winters_chill)
  if S.GlacialSpike:IsReady() and (Icicles == 5 and (S.Flurry:CooldownUp() or RemainingWintersChill > 0)) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike cleave 10"; end
  end
  -- frozen_orb,if=buff.fingers_of_frost.react<2&(!talent.ray_of_frost|cooldown.ray_of_frost.remains)
  if S.FrozenOrb:IsCastable() and (Player:BuffStackP(S.FingersofFrostBuff) < 2 and (not S.RayofFrost:IsAvailable() or S.RayofFrost:CooldownDown())) then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb cleave 12"; end
  end
  -- cone_of_cold,if=talent.coldest_snap&cooldown.comet_storm.remains>10&cooldown.frozen_orb.remains>10&remaining_winters_chill=0&active_enemies>=3
  if S.ConeofCold:IsCastable() and (S.ColdestSnap:IsAvailable() and S.CometStorm:CooldownRemains() > 10 and S.FrozenOrb:CooldownRemains() > 10 and RemainingWintersChill == 0 and EnemiesCount16ySplash >= 3) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold cleave 14"; end
  end
  -- shifting_power,if=cooldown.frozen_orb.remains>10&(!talent.comet_storm|cooldown.comet_storm.remains>10)&(!talent.ray_of_frost|cooldown.ray_of_frost.remains>10)|cooldown.icy_veins.remains<20
  if S.ShiftingPower:IsCastable() and (S.FrozenOrb:CooldownRemains() > 10 and (not S.CometStorm:IsAvailable() or S.CometStorm:CooldownRemains() > 10) and (not S.RayofFrost:IsAvailable() or S.RayofFrost:CooldownRemains() > 10) or S.IcyVeins:CooldownRemains() < 20) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power cleave 16"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike cleave 18"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=buff.fingers_of_frost.react&!prev_gcd.1.glacial_spike|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUpP(S.FingersofFrostBuff) and not Player:PrevGCDP(1, S.GlacialSpike) or RemainingWintersChill > 0) then
    if Everyone.CastTargetIf(S.IceLance, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance cleave 20"; end
  end
  -- ice_nova,if=active_enemies>=4
  if S.IceNova:IsCastable() and (EnemiesCount16ySplash >= 4) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova cleave 22"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt cleave 24"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function SSST()
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&(prev_gcd.1.frostbolt|prev_gcd.1.glacial_spike)
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and (Player:PrevGCDP(1, S.Frostbolt) or Player:PrevGCDP(1, S.GlacialSpike))) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_st 2"; end
  end
  -- ice_lance,if=buff.icy_veins.up&(debuff.winters_chill.stack=2|debuff.winters_chill.stack=1&action.splinterstorm.in_flight
  if S.IceLance:IsReady() and (Player:BuffUp(S.IcyVeinsBuff) and (Target:DebuffStack(S.WintersChillDebuff) == 2 or Target:DebuffStack(S.WintersChillDebuff) == 1 and S.Splinterstorm:InFlight())) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_st 4"; end
  end
  -- ray_of_frost,if=buff.icy_veins.down&buff.freezing_winds.down&remaining_winters_chill=1
  if S.RayofFrost:IsCastable() and (Player:BuffDown(S.IcyVeinsBuff) and Player:BuffDown(S.FreezingWindsBuff) and RemainingWintersChill == 1) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost ss_st 6"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb ss_st 8"; end
  end
  -- shifting_power
  if CDsON() and S.ShiftingPower:IsCastable() then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power ss_st 10"; end
  end
  -- ice_lance,if=remaining_winters_chill
  if S.IceLance:IsReady() and (RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_st 12"; end
  end
  -- comet_storm,if=prev_gcd.1.flurry|prev_gcd.1.cone_of_cold|action.splinterstorm.in_flight
  -- TODO: Figure out a way to handle action.splinterstorm.in_flight
  if S.CometStorm:IsCastable() and (Player:PrevGCDP(1, S.Flurry) or Player:PrevGCDP(1, S.ConeofCold)) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm ss_st 14"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike ss_st 16"; end
  end
  -- flurry,if=cooldown_react&buff.icy_veins.up&!action.splinterstorm.in_flight
  if S.Flurry:IsCastable() and (Player:BuffUp(S.IcyVeinsBuff) and not S.Splinterstorm:InFlight()) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry ss_st 18"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance ss_st 20"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt ss_st 22"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function ST()
  -- comet_storm,if=prev_gcd.1.flurry|prev_gcd.1.cone_of_cold
  if S.CometStorm:IsCastable() and (Player:PrevGCDP(1, S.Flurry) or Player:PrevGCDP(1, S.ConeofCold)) then
    if Cast(S.CometStorm, Settings.Frost.GCDasOffGCD.CometStorm, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single 2"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&(((prev_gcd.1.frostbolt|prev_gcd.1.frostfire_bolt)&buff.icicles.react>=3|(prev_gcd.1.frostbolt|prev_gcd.1.frostfire_bolt)&buff.brain_freeze.react)|prev_gcd.1.glacial_spike|talent.glacial_spike&buff.icicles.react=4&!buff.fingers_of_frost.react)|buff.excess_frost.up&buff.frostfire_empowerment.up
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and ((Player:PrevGCDP(1, Bolt) and Icicles >= 3 or Player:PrevGCDP(1, Bolt) and Player:BuffUp(S.BrainFreezeBuff)) or Player:PrevGCDP(1, S.GlacialSpike) or S.GlacialSpike:IsAvailable() and Icicles == 4 and Player:BuffDown(S.FingersofFrostBuff)) or Player:BuffUp(S.ExcessFrostBuff) and Player:BuffUp(S.FrostfireEmpowermentBuff)) then
    if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single 4"; end
  end
  -- ice_lance,if=talent.glacial_spike&debuff.winters_chill.down&buff.icicles.react=4&buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (S.GlacialSpike:IsAvailable() and RemainingWintersChill == 0 and Icicles == 4 and Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 6"; end
  end
  -- ray_of_frost,if=remaining_winters_chill=1
  if S.RayofFrost:IsCastable() and (RemainingWintersChill == 1) then
    if Cast(S.RayofFrost, Settings.Frost.GCDasOffGCD.RayOfFrost, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single 8"; end
  end
  -- glacial_spike,if=buff.icicles.react=5&(action.flurry.cooldown_react|remaining_winters_chill)
  if S.GlacialSpike:IsReady() and (Icicles == 5 and (S.Flurry:Charges() >= 1 or RemainingWintersChill > 0)) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 10"; end
  end
  -- frozen_orb,if=buff.fingers_of_frost.react<2&(!talent.ray_of_frost|cooldown.ray_of_frost.remains)
  if S.FrozenOrb:IsCastable() and (Player:BuffStackP(S.FingersofFrostBuff) < 2 and (not S.RayofFrost:IsAvailable() or S.RayofFrost:CooldownDown())) then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb single 12"; end
  end
  -- cone_of_cold,if=talent.coldest_snap&cooldown.comet_storm.remains>10&cooldown.frozen_orb.remains>10&remaining_winters_chill=0&active_enemies>=3
  if S.ConeofCold:IsCastable() and (S.ColdestSnap:IsAvailable() and S.CometStorm:CooldownRemains() > 10 and S.FrozenOrb:CooldownRemains() > 10 and RemainingWintersChill == 0 and EnemiesCount8ySplash >= 3) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold single 14"; end
  end
  -- blizzard,if=active_enemies>=2&talent.ice_caller&talent.freezing_rain&(!talent.splintering_cold&!talent.ray_of_frost|buff.freezing_rain.up|active_enemies>=3)
  if AoEON() and S.Blizzard:IsCastable() and (EnemiesCount8ySplash >= 2 and S.IceCaller:IsAvailable() and S.FreezingRain:IsAvailable() and (not S.SplinteringCold:IsAvailable() and not S.RayofFrost:IsAvailable() or Player:BuffUp(S.FreezingRainBuff) or EnemiesCount8ySplash >= 3)) then
    if Cast(S.Blizzard, Settings.Frost.GCDasOffGCD.Blizzard, nil, not Target:IsInRange(40)) then return "blizzard single 16"; end
  end
  -- shifting_power,if=(buff.icy_veins.down|!talent.deaths_chill)&cooldown.frozen_orb.remains>10&(!talent.comet_storm|cooldown.comet_storm.remains>10)&(!talent.ray_of_frost|cooldown.ray_of_frost.remains>10)|cooldown.icy_veins.remains<20
  if S.ShiftingPower:IsCastable() and ((Player:BuffDown(S.IcyVeinsBuff) or not S.DeathsChill:IsAvailable()) and S.FrozenOrb:CooldownRemains() > 10 and (not S.CometStorm:IsAvailable() or S.CometStorm:CooldownRemains() > 10) and (not S.RayofFrost:IsAvailable() or S.RayofFrost:CooldownRemains() > 10) or S.IcyVeins:CooldownRemains() < 20) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power single 18"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsCastable() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 20"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react&!prev_gcd.1.glacial_spike|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) and not Player:PrevGCDP(1, S.GlacialSpike) or bool(RemainingWintersChill)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 22"; end
  end
  -- ice_nova,if=active_enemies>=4
  if AoEON() and S.IceNova:IsCastable() and (EnemiesCount16ySplash >= 4) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova single 24"; end
  end
  -- frostbolt
  if Bolt:IsCastable() then
    if Cast(Bolt, nil, nil, not Target:IsSpellInRange(Bolt)) then return "frostbolt single 26"; end
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
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.CommonsDS.DisplayStyle.Interrupts, false); if ShouldReturn then return ShouldReturn; end
    -- Force Flurry in opener
    if S.Flurry:IsCastable() and (HL.CombatTime() < 5 and (Player:IsCasting(Bolt) or Player:PrevGCDP(1, Bolt))) then
      if Cast(S.Flurry, Settings.Frost.GCDasOffGCD.Flurry, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry opener"; end
    end
    -- call_action_list,name=cds
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=aoe,if=active_enemies>=7|active_enemies>=3&talent.ice_caller
    if AoEON() and (EnemiesCount16ySplash >= 7 or EnemiesCount16ySplash >= 3 and S.IceCaller:IsAvailable()) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool for Aoe()"; end
    end
    -- run_action_list,name=ss_cleave,if=active_enemies>=2&active_enemies<=3&talent.splinterstorm
    if AoEON() and (EnemiesCount16ySplash >= 2 and EnemiesCount16ySplash <= 3 and S.Splinterstorm:IsAvailable()) then
      local ShouldReturn = SSCleave(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool for SSCleave()"; end
    end
    -- run_action_list,name=cleave,if=active_enemies>=2&active_enemies<=3
    if AoEON() and EnemiesCount16ySplash >= 2 and EnemiesCount16ySplash <= 3 then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool for Cleave()"; end
    end
    -- run_action_list,name=ss_st,if=talent.splinterstorm
    if S.Splinterstorm:IsAvailable() then
      local ShouldReturn = SSST(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool for SSST()"; end
    end
    -- run_action_list,name=st
    local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool for ST()"; end
  end
end

local function Init()
  S.WintersChillDebuff:RegisterAuraTracking()

  HR.Print("Frost Mage rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(64, APL, Init)
