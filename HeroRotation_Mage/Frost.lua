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
local max        = math.max

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Frost
local I = Item.Mage.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local EnemiesCount8ySplash, EnemiesCount16ySplash --Enemies arround target
local EnemiesCount15yMelee  --Enemies arround player
local Enemies16ySplash
local RemainingWintersChill = 0
local var_snowstorm_max_stack = 30
local var_use_fof = true
local BossFightRemains = 11111
local FightRemains = 11111

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

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
  RemainingWintersChill = 0
end, "PLAYER_REGEN_ENABLED")

local function FrozenRemains()
  return max(Target:DebuffRemains(S.Frostbite), Target:DebuffRemains(S.Freeze), Target:DebuffRemains(S.FrostNova))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and (Player:BuffDown(S.ArcaneIntellect, true) or Everyone.GroupBuffMissing(S.ArcaneIntellect)) then
    if Cast(S.ArcaneIntellect, Settings.Commons.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect precombat 2"; end
  end
  -- summon_water_elemental
  if S.SummonWaterElemental:IsCastable() then
    if Cast(S.SummonWaterElemental) then return "summon_water_elemental precombat 4"; end
  end
  -- variable,name=use_fof,default=1,op=reset
  -- Note: I don't see anywhere that this value is altered, so it's set in variable definitions above.
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- blizzard,if=active_enemies>=2
    -- TODO precombat active_enemies
    -- frostbolt,if=active_enemies=1
    if S.Frostbolt:IsCastable() and not Player:IsCasting(S.Frostbolt) then
      if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt precombat 10"; end
    end
  end
end

local function Cooldowns()
  -- time_warp,if=buff.exhaustion.up&buff.bloodlust.down
  if S.TimeWarp:IsCastable() and S.TemporalWarp:IsAvailable() and Settings.Frost.UseTemporalWarp and (Player:BloodlustExhaustUp() and Player:BloodlustDown()) then
    if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp cd 2"; end
  end
  -- potion,if=prev_off_gcd.icy_veins|fight_remains<60
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.IcyVeinsBuff) or FightRemains < 60) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cd 4"; end
    end
  end
  -- icy_veins,if=buff.rune_of_power.down&(buff.icy_veins.down|talent.rune_of_power)
  if S.IcyVeins:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and (Player:BuffDown(S.IcyVeinsBuff) or S.RuneofPower:IsAvailable())) then
    if Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cd 6"; end
  end
  -- rune_of_power,if=buff.rune_of_power.down&cooldown.icy_veins.remains>20
  if S.RuneofPower:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and S.IcyVeins:CooldownRemains() > 20) then
    if Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneOfPower) then return "rune_of_power cd 8"; end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.power_infusion.down
  -- invoke_external_buff,name=blessing_of_summer,if=buff.blessing_of_summer.down
  -- Note: Not handling external buffs.
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd 10"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd 12"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cd 14"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd 16"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd 18"; end
  end
end

local function Aoe()
  -- cone_of_cold,if=buff.snowstorm.stack=buff.snowstorm.max_stack&debuff.frozen.up&(prev_gcd.1.frost_nova|prev_gcd.1.ice_nova|prev_off_gcd.freeze)
  if S.ConeofCold:IsCastable() and (Player:BuffStackP(S.SnowstormBuff) == var_snowstorm_max_stack and FrozenRemains() > 0 and (Player:PrevGCDP(1, S.FrostNova) or Player:PrevGCDP(1, S.IceNova) or Player:PrevGCDP(1, S.Freeze))) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold aoe 2"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb aoe 4"; end
  end
  -- blizzard
  if S.Blizzard:IsCastable() then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 6"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastable() then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe 8"; end
  end
  -- freeze,if=(target.level<level+3|target.is_add)&(!talent.snowstorm&debuff.frozen.down|cooldown.cone_of_cold.ready&buff.snowstorm.stack=buff.snowstorm.max_stack)
  if Pet:IsActive() and S.Freeze:IsReady() and (Target:Level() < Player:Level() + 3 and ((not S.Snowstorm:IsAvailable()) and FrozenRemains() == 0 or S.ConeofCold:CooldownUp() and Player:BuffStackP(S.SnowstormBuff) == var_snowstorm_max_stack)) then
    if Cast(S.Freeze, nil, nil, not Target:IsSpellInRange(S.Freeze)) then return "freeze aoe 10"; end
  end
  -- ice_nova,if=(target.level<level+3|target.is_add)&(prev_gcd.1.comet_storm|cooldown.cone_of_cold.ready&buff.snowstorm.stack=buff.snowstorm.max_stack&gcd.max<1)
  if S.IceNova:IsCastable() and (Target:Level() < Player:Level() + 3 and (Player:PrevGCDP(1, S.CometStorm) or S.ConeofCold:CooldownUp() and Player:BuffStackP(S.SnowstormBuff) == var_snowstorm_max_stack and Player:GCD() < 1)) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 11"; end
  end
  -- frost_nova,if=(target.level<level+3|target.is_add)&active_enemies>=5&cooldown.cone_of_cold.ready&buff.snowstorm.stack=buff.snowstorm.max_stack&gcd.max<1
  if S.FrostNova:IsCastable() and (Target:Level() < Player:Level() + 3 and (EnemiesCount16ySplash >= 5 and S.ConeofCold:CooldownUp() and Player:BuffStackP(S.SnowstormBuff) == var_snowstorm_max_stack and Player:GCD() < 1)) then
    if Cast(S.FrostNova, nil, nil, not Target:IsInRange(12)) then return "frost_nova aoe 12"; end
  end
  -- cone_of_cold,if=buff.snowstorm.stack=buff.snowstorm.max_stack
  if S.ConeofCold:IsCastable() and (Player:BuffStackP(S.SnowstormBuff) == var_snowstorm_max_stack) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold aoe 14"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&(!variable.use_fof|debuff.winters_chill.down&(prev_gcd.1.frostbolt|(active_enemies>=7|charges=max_charges)&buff.fingers_of_frost.react=0))
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and ((not var_use_fof) or Target:DebuffDown(S.WintersChillDebuff) and (Player:PrevGCDP(1, S.Frostbolt) or (EnemiesCount16ySplash >= 7 or S.Flurry:Charges() == S.Flurry:MaxCharges()) and Player:BuffDown(S.FingersofFrostBuff)))) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 16"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time|remaining_winters_chill
  if S.IceLance:IsCastable() and (Player:BuffUp(S.FingersofFrostBuff) or FrozenRemains() > S.IceLance:TravelTime() or RemainingWintersChill > 0) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 18"; end
  end
  -- shifting_power
  if S.ShiftingPower:IsCastable() and CDsON() then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power aoe 20"; end
  end
  -- ice_nova
  if S.IceNova:IsCastable() then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 22"; end
  end
  -- meteor
  if S.Meteor:IsCastable() then
    if Cast(S.Meteor, nil, nil, not Target:IsInRange(40)) then return "meteor aoe 24"; end
  end
  -- dragons_breath,if=active_enemies>=7
  if S.DragonsBreath:IsCastable() and (EnemiesCount16ySplash >= 7) then
    if Cast(S.DragonsBreath, nil, nil, not Target:IsInRange(12)) then return "dragons_breath aoe 26"; end
  end
  -- arcane_explosion,if=mana.pct>30&active_enemies>=7
  if S.ArcaneExplosion:IsCastable() and (Player:ManaPercentage() > 30 and EnemiesCount16ySplash >= 7) then
    if Settings.Frost.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion aoe 28 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion aoe 28"; end
    end
  end
  -- ebonbolt
  if S.Ebonbolt:IsCastable() and (EnemiesCount8ySplash >= 2) then
    if Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt aoe 30"; end
  end
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 32"; end
  end
  -- Manually added: ice_lance as a fallthrough when MovingRotation is true
  if S.IceLance:IsCastable() then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 34"; end
  end
end

local function Single()
  -- meteor,if=prev_gcd.1.flurry
  if S.Meteor:IsCastable() and Player:PrevGCDP(1, S.Flurry) then
    if Cast(S.Meteor, nil, nil, not Target:IsSpellInRange(S.Meteor)) then return "meteor single 2"; end
  end
  -- comet_storm,if=prev_gcd.1.flurry
  if S.CometStorm:IsCastable() and Player:PrevGCDP(1, S.Flurry) then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single 4"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&(prev_gcd.1.frostbolt|prev_gcd.1.glacial_spike)
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and (Player:IsCasting(S.Ebonbolt) or Player:IsCasting(S.Frostbolt))) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single 6"; end
  end
  -- ray_of_frost,if=remaining_winters_chill=1&buff.freezing_winds.down
  if S.RayofFrost:IsCastable() and (RemainingWintersChill == 1 and Player:BuffDown(S.FreezingWindsBuff)) then
    if Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single 8"; end
  end
  -- glacial_spike,if=remaining_winters_chill
  if S.GlacialSpike:IsReady() and (RemainingWintersChill > 0) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 10"; end
  end
  -- cone_of_cold,if=buff.snowstorm.stack=buff.snowstorm.max_stack&remaining_winters_chill
  if S.ConeofCold:IsCastable() and (Player:BuffStackP(S.SnowstormBuff) == var_snowstorm_max_stack and RemainingWintersChill > 0) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold single 12"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb single 14"; end
  end
  -- blizzard,if=active_enemies>=2&talent.ice_caller&talent.freezing_rain
  if S.Blizzard:IsCastable() and EnemiesCount16ySplash >= 2 and S.IceCaller:IsAvailable() and S.FreezingRain:IsAvailable() then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single 16"; end
  end
  -- shifting_power,if=(variable.use_fof&buff.rune_of_power.down)|(!variable.use_fof&(buff.rune_of_power.down&buff.icy_veins.down|cooldown.icy_veins.remains<20))
  if S.ShiftingPower:IsCastable() and ((var_use_fof and Player:BuffDown(S.RuneofPowerBuff)) or ((not var_use_fof) and (Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.IcyVeinsBuff) or S.IcyVeins:CooldownRemains() < 20))) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power single 18"; end
  end
  -- ice_lance,if=(variable.use_fof&(buff.fingers_of_frost.react&!prev_gcd.1.glacial_spike|remaining_winters_chill))|(!variable.use_fof&(remaining_winters_chill=2|remaining_winters_chill=1&buff.brain_freeze.react|(remaining_winters_chill|buff.fingers_of_frost.react)&(buff.icy_veins.remains<10&cooldown.icy_veins.remains>30|buff.icy_veins.remains<15&cooldown.icy_veins.remains>70)))
  if S.IceLance:IsCastable() and ((var_use_fof and (Player:BuffUp(S.FingersofFrostBuff) and (not Player:PrevGCDP(1, S.GlacialSpike)) or RemainingWintersChill > 0)) or ((not var_use_fof) and (RemainingWintersChill == 2 or RemainingWintersChill == 1 and Player:BuffUp(S.BrainFreezeBuff) or (RemainingWintersChill > 0 or Player:BuffUp(S.FingersofFrostBuff)) and (Player:BuffRemains(S.IcyVeinsBuff) < 10 and S.IcyVeins:CooldownRemains() > 30 or Player:BuffRemains(S.IcyVeinsBuff) < 15 and S.IcyVeins:CooldownRemains() > 70)))) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 20"; end
  end
  -- ice_nova,if=active_enemies>=4
  if S.IceNova:IsCastable() and (EnemiesCount16ySplash >= 4) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova single 22"; end
  end
  -- glacial_spike,if=buff.brain_freeze.react
  if S.GlacialSpike:IsCastable() and Player:BuffUp(S.BrainFreezeBuff) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 34"; end
  end
  -- ebonbolt,if=cooldown.flurry.charges_fractional<1
  if S.Ebonbolt:IsCastable() and S.Flurry:Charges() < 1 then
    if Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt single 36"; end
  end
  if CDsON() then
    -- bag_of_tricks
    if S.BagofTricks:IsCastable() then
      if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cd 40"; end
    end
  end
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt single 42"; end
  end
  -- Manually added: ice_lance as a fallthrough when MovingRotation is true
  if S.IceLance:IsCastable() then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 44"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Enemies Update
  Enemies16ySplash = Target:GetEnemiesInSplashRange(16)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
  else
    EnemiesCount15yMelee = 1
    EnemiesCount8ySplash = 1
    EnemiesCount16ySplash = 1
  end

  -- Check our IF status
  -- Note: Not referenced in the current APL, but saving for potential use later
  --Mage.IFTracker()

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies16ySplash, false)
    end

    -- Calculate remaining_winters_chill, as it's used in many lines
    RemainingWintersChill = Target:DebuffStack(S.WintersChillDebuff)
  end

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    -- water_jet,if=cooldown.flurry.charges_fractional<1
    if Pet:IsActive() and S.WaterJet:IsReady() and (S.Flurry:ChargesFractional() < 1) then
      if Cast(S.WaterJet, nil, nil, not Target:IsSpellInRange(S.WaterJet)) then return "water_jet main 2"; end
    end
    -- call_action_list,name=cds
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=7|active_enemies>=3&talent.ice_caller
    if AoEON() and (EnemiesCount16ySplash >= 7 or EnemiesCount16ySplash >= 3 and S.IceCaller:IsAvailable()) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=single,if=active_enemies<7&(active_enemies<3|!talent.ice_caller)
    if (not AoEON()) or (EnemiesCount16ySplash < 7 and (EnemiesCount16ySplash < 3 or not S.IceCaller:IsAvailable())) then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=movement
  end
end

local function Init()
  HR.Print("Frost Mage rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(64, APL, Init)
