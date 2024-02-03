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
  I.BalefireBranch:ID(),
  I.BelorrelostheSuncaller:ID(),
  I.Dreambinder:ID(),
  I.SpoilsofNeltharus:ID(),
}

-- Rotation Var
local EnemiesCount8ySplash, EnemiesCount16ySplash --Enemies arround target
local EnemiesCount15yMelee  --Enemies arround player
local Enemies16ySplash
local RemainingWintersChill = 0
local Icicles = 0
local var_snowstorm_max_stack = 15
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Frost = HR.GUISettings.APL.Mage.Frost
}

S.Frostbolt:RegisterInFlightEffect(228597)
S.Frostbolt:RegisterInFlight()
S.FrozenOrb:RegisterInFlightEffect(84721)
S.FrozenOrb:RegisterInFlight()
S.Flurry:RegisterInFlightEffect(228354)
S.Flurry:RegisterInFlight()
S.GlacialSpike:RegisterInFlightEffect(228600)
S.GlacialSpike:RegisterInFlight()
S.IceLance:RegisterInFlightEffect(228598)
S.IceLance:RegisterInFlight()

HL:RegisterForEvent(function()
  S.FrozenOrb:RegisterInFlightEffect(84721)
  S.FrozenOrb:RegisterInFlight()
  S.Flurry:RegisterInFlightEffect(228354)
  S.Flurry:RegisterInFlight()
  S.GlacialSpike:RegisterInFlightEffect(228600)
  S.GlacialSpike:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
  RemainingWintersChill = 0
end, "PLAYER_REGEN_ENABLED")

local function Freezable(Tar)
  if Tar == nil then Tar = Target end
  return (not Tar:IsInBossList() or Tar:Level() < 73)
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

-- CastTargetIf/CastCycle Functions
local function EvaluateTargetIfFilterWCStacks(TargetUnit)
  -- target_if=min:debuff.winters_chill.stack
  return (TargetUnit:DebuffStack(S.WintersChillDebuff))
end

local function EvaluateTargetIfILCleave(TargetUnit)
  -- if=talent.glacial_spike&debuff.winters_chill.down&buff.icicles.react=4&buff.fingers_of_frost.react
  -- Note: All but debuff handled before the CastCycle
  return (TargetUnit:DebuffDown(S.WintersChillDebuff))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Everyone.GroupBuffMissing(S.ArcaneIntellect) then
    if Cast(S.ArcaneIntellect, Settings.Commons.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect precombat 2"; end
  end
  -- snapshot_stats
  -- blizzard,if=active_enemies>=2&talent.ice_caller|active_enemies>=3
  -- Note: Can't check active_enemies in Precombat
  -- frostbolt,if=active_enemies<=2
  if S.Frostbolt:IsCastable() and not Player:IsCasting(S.Frostbolt) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt precombat 4"; end
  end
end

local function Cooldowns()
  -- time_warp,if=buff.exhaustion.up&talent.temporal_warp&buff.bloodlust.down&(prev_off_gcd.icy_veins|(buff.icy_veins.up&fight_remains<=110|buff.icy_veins.up&fight_remains>=280)|fight_remains<40)
  -- Note: Keeping this as TemporalWarp time_warp, as we won't suggest time_warp otherwise.
  if Settings.Commons.UseTemporalWarp and S.TimeWarp:IsCastable() and (Player:BloodlustExhaustUp() and S.TemporalWarp:IsAvailable() and Player:BloodlustDown() and (Player:PrevOffGCDP(1, S.IcyVeins) or (Player:BuffUp(S.IcyVeinsBuff) and FightRemains <= 110 or Player:BuffUp(S.IcyVeinsBuff) and FightRemains >= 280) or FightRemains < 40)) then
    if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp cd 2"; end
  end
  -- use_item,name=spoils_of_neltharus,if=buff.spoils_of_neltharus_mastery.up|buff.spoils_of_neltharus_haste.up&buff.bloodlust.down&buff.temporal_warp.down&time>0|buff.spoils_of_neltharus_vers.up&(buff.bloodlust.up|buff.temporal_warp.up)
  if I.SpoilsofNeltharus:IsEquippedAndReady() and (Player:BuffUp(S.SpoilsofNeltharusMastery) or Player:BuffUp(S.SpoilsofNeltharusHaste) and Player:BloodlustDown() and Player:BuffDown(S.TemporalWarpBuff) or Player:BuffUp(S.SpoilsofNeltharusVers) and (Player:BloodlustUp() or Player:BuffUp(S.TemporalWarpBuff))) then
    if Cast(I.SpoilsofNeltharus, nil, Settings.Commons.DisplayStyle.Trinkets) then return "spoils_of_neltharus cd 4"; end
  end
  -- potion,if=prev_off_gcd.icy_veins|fight_remains<60
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.IcyVeinsBuff) or FightRemains < 60) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cd 6"; end
    end
  end
  -- use_item,name=dreambinder_loom_of_the_great_cycle,if=(equipped.nymues_unraveling_spindle&prev_gcd.1.nymues_unraveling_spindle)|fight_remains>2
  if Settings.Commons.Enabled.Items and I.Dreambinder:IsEquippedAndReady() and ((I.NymuesUnravelingSpindle:IsEquipped() and Player:PrevGCDP(1, I.NymuesUnravelingSpindle)) or FightRemains > 2) then
    if Cast(I.Dreambinder, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(45)) then return "dreambinder_loom_of_the_great_cycle cd 8"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=belorrelos_the_suncaller,use_off_gcd=1,if=(gcd.remains>gcd.max-0.1|fight_remains<5)&time>5
    if I.BelorrelostheSuncaller:IsEquippedAndReady() and (HL.CombatTime() > 5) then
      if Cast(I.BelorrelostheSuncaller, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller cd 10"; end
    end
    -- use_item,name=balefire_branch,if=(!talent.ray_of_frost&active_enemies<=2&buff.icy_veins.up&prev_gcd.1.glacial_spike|remaining_winters_chill=1&cooldown.ray_of_frost.up&time>1&active_enemies<=2|cooldown.cone_of_cold.up&prev_gcd.1.comet_storm&active_enemies>=3)|fight_remains<20
    if I.BalefireBranch:IsEquippedAndReady() and ((not S.RayofFrost:IsAvailable() and EnemiesCount16ySplash <= 2 and Player:BuffUp(S.IcyVeinsBuff) and Player:PrevGCDP(1, S.GlacialSpike) or RemainingWintersChill == 1 and S.RayofFrost:CooldownUp() and HL.CombatTime() > 1 and EnemiesCount16ySplash <= 2 or S.ConeofCold:CooldownUp() and Player:PrevGCDP(1, S.CometStorm) and EnemiesCount16ySplash >= 3) or FightRemains < 20) then
      if Cast(I.BalefireBranch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "balefire_branch cd 12"; end
    end
  end
  -- flurry,if=time=0&active_enemies<=2
  -- Note: Can't get target count at time=0
  -- icy_veins
  if S.IcyVeins:IsCastable() then
    if Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cd 14"; end
  end
  -- use_items,if=!equipped.balfire_branch|time>5
  if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and (not I.BalefireBranch:IsEquipped() or HL.CombatTime() > 5) then
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
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd 16"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd 18"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cd 20"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd 22"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd 24"; end
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
  -- arcane_explosion,if=mana.pct>30&active_enemies>=2
  -- Note: If we're not in ArcaneExplosion range, just move to the next suggestion.
  if S.ArcaneExplosion:IsReady() and Target:IsInRange(10) and (Player:ManaPercentage() > 30 and EnemiesCount8ySplash >= 2) then
    if Cast(S.ArcaneExplosion, nil, Settings.Frost.DisplayStyle.Movement) then return "arcane_explosion movement 6"; end
  end
  -- fire_blast
  if S.FireBlast:IsReady() then
    if Cast(S.FireBlast, nil, Settings.Frost.DisplayStyle.Movement, not Target:IsSpellInRange(S.FireBlast)) then return "fire_blast movement 8"; end
  end
  -- ice_lance
  if S.IceLance:IsReady() then
    if Cast(S.IceLance, nil, Settings.Frost.DisplayStyle.Movement, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance movement 10"; end
  end
end

local function Aoe()
  -- cone_of_cold,if=talent.coldest_snap&(prev_gcd.1.comet_storm|prev_gcd.1.frozen_orb&!talent.comet_storm)
  if S.ConeofCold:IsCastable() and (S.ColdestSnap:IsAvailable() and (Player:PrevGCDP(1, S.CometStorm) or Player:PrevGCDP(1, S.FrozenOrb) and not S.CometStorm:IsAvailable())) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold aoe 2"; end
  end
  -- frozen_orb,if=!prev_gcd.1.glacial_spike|!freezable
  if S.FrozenOrb:IsCastable() and (not Player:PrevGCDP(1, S.GlacialSpike) or not Freezable()) then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb aoe 4"; end
  end
  -- blizzard,if=!prev_gcd.1.glacial_spike|!freezable
  if S.Blizzard:IsCastable() and (not Player:PrevGCDP(1, S.GlacialSpike) or not Freezable()) then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 6"; end
  end
  -- comet_storm,if=!prev_gcd.1.glacial_spike&(!talent.coldest_snap|cooldown.cone_of_cold.ready&cooldown.frozen_orb.remains>25|cooldown.cone_of_cold.remains>20)
  if S.CometStorm:IsCastable() and (not Player:PrevGCDP(1, S.GlacialSpike) and (not S.ColdestSnap:IsAvailable() or S.ConeofCold:CooldownUp() and S.FrozenOrb:CooldownRemains() > 25 or S.ConeofCold:CooldownRemains() > 20)) then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe 8"; end
  end
  -- freeze,if=freez&debuff.frozen.down&(!talent.glacial_spike&!talent.snowstorm|prev_gcd.1.glacial_spike|cooldown.cone_of_cold.ready&buff.snowstorm.stack=buff.snowstorm.max_stack)
  if Pet:IsActive() and S.Freeze:IsReady() and (Freezable() and FrozenRemains() == 0 and (not S.GlacialSpike:IsAvailable() and not S.Snowstorm:IsAvailable() or Player:PrevGCDP(1, S.GlacialSpike) or S.ConeofCold:CooldownUp() and Player:BuffStack(S.SnowstormBuff) == var_snowstorm_max_stack)) then
    if Cast(S.Freeze, nil, nil, not Target:IsSpellInRange(S.Freeze)) then return "freeze aoe 10"; end
  end
  -- ice_nova,if=freezable&!prev_off_gcd.freeze&(prev_gcd.1.glacial_spike|cooldown.cone_of_cold.ready&buff.snowstorm.stack=buff.snowstorm.max_stack&gcd.max<1)
  if S.IceNova:IsCastable() and (Freezable() and not Player:PrevOffGCDP(1, S.Freeze) and (Player:PrevGCDP(1, S.GlacialSpike) or S.ConeofCold:CooldownUp() and Player:BuffStack(S.SnowstormBuff) == var_snowstorm_max_stack and GCDMax < 1)) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 12"; end
  end
  -- frost_nova,if=freezable&!prev_off_gcd.freeze&(prev_gcd.1.glacial_spike&!remaining_winters_chill|cooldown.cone_of_cold.ready&buff.snowstorm.stack=buff.snowstorm.max_stack&gcd.max<1)
  if S.FrostNova:IsCastable() and (Freezable() and not Player:PrevOffGCDP(1, S.Freeze) and (Player:PrevGCDP(1, S.GlacialSpike) and RemainingWintersChill == 0 or S.ConeofCold:CooldownUp() and Player:BuffStack(S.SnowstormBuff) == var_snowstorm_max_stack and GCDMax < 1)) then
    if Cast(S.FrostNova, nil, nil, not Target:IsInRange(12)) then return "frost_nova aoe 14"; end
  end
  -- cone_of_cold,if=buff.snowstorm.stack=buff.snowstorm.max_stack
  if S.ConeofCold:IsCastable() and (Player:BuffStackP(S.SnowstormBuff) == var_snowstorm_max_stack) then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(12)) then return "cone_of_cold aoe 16"; end
  end
  -- shifting_power
  if S.ShiftingPower:IsCastable() and CDsON() then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power aoe 18"; end
  end
  -- glacial_spike,if=buff.icicles.react=5&cooldown.blizzard.remains>gcd.max
  if S.GlacialSpike:IsReady() and (Icicles == 5 and S.Blizzard:CooldownRemains() > GCDMax) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike aoe 20"; end
  end
  -- flurry,if=!freezable&cooldown_react&!debuff.winters_chill.remains&(prev_gcd.1.glacial_spike|charges_fractional>1.8)
  if S.Flurry:IsCastable() and (not Freezable() and RemainingWintersChill == 0 and (Player:PrevGCDP(1, S.GlacialSpike) or S.Flurry:ChargesFractional() > 1.8)) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 22"; end
  end
  -- flurry,if=cooldown_react&!debuff.winters_chill.remains&(buff.brain_freeze.react|!buff.fingers_of_frost.react)
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and (Player:BuffUp(S.BrainFreezeBuff) or Player:BuffUp(S.FingersofFrostBuff))) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 24"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUp(S.FingersofFrostBuff) or FrozenRemains() > S.IceLance:TravelTime() or bool(RemainingWintersChill)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 26"; end
  end
  -- ice_nova,if=active_enemies>=4&(!talent.snowstorm&!talent.glacial_spike|!freezable)
  if S.IceNova:IsCastable() and (EnemiesCount8ySplash >= 4 and (not S.Snowstorm:IsAvailable() and not S.GlacialSpike:IsAvailable() or not Freezable())) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 28"; end
  end
  -- dragons_breath,if=active_enemies>=7
  if S.DragonsBreath:IsCastable() and (EnemiesCount16ySplash >= 7) then
    if Cast(S.DragonsBreath, nil, nil, not Target:IsInRange(12)) then return "dragons_breath aoe 30"; end
  end
  -- arcane_explosion,if=mana.pct>30&active_enemies>=7
  if S.ArcaneExplosion:IsCastable() and (Player:ManaPercentage() > 30 and EnemiesCount16ySplash >= 7) then
    if Settings.Frost.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion aoe 32 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion aoe 32"; end
    end
  end
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 34"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function Cleave()
  -- comet_storm,if=prev_gcd.1.flurry|prev_gcd.1.cone_of_cold
  if S.CometStorm:IsCastable() and (Player:PrevGCDP(1, S.Flurry) or Player:PrevGCDP(1, S.ConeofCold)) then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm cleave 2"; end
  end
  -- flurry,target_if=min:debuff.winters_chill.stack,if=cooldown_react&((prev_gcd.1.frostbolt&buff.icicles.react>=3)|prev_gcd.1.glacial_spike|(buff.icicles.react>=3&buff.icicles.react<5&charges_fractional=2))
  if S.Flurry:IsCastable() and ((Player:PrevGCDP(1, S.Frostbolt) and Icicles >= 3) or Player:PrevGCDP(1, S.GlacialSpike) or (Icicles >= 3 and Icicles < 5 and S.Flurry:ChargesFractional() == 2)) then
    if Everyone.CastTargetIf(S.Flurry, Enemies16ySplash, "min", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry cleave 4"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=talent.glacial_spike&debuff.winters_chill.down&buff.icicles.react=4&buff.fingers_of_frost.react
  -- Note: Competing target_if and debuff.winters_chill.down mean this should only happen if no targets have WC. Using AuraActiveCount() instead.
  if S.IceLance:IsReady() and (S.GlacialSpike:IsAvailable() and S.WintersChillDebuff:AuraActiveCount() == 0 and Icicles == 4 and Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance cleave 6"; end
  end
  -- ray_of_frost,target_if=max:debuff.winters_chill.stack,if=remaining_winters_chill=1
  if S.RayofFrost:IsCastable() and (RemainingWintersChill == 1) then
    if Everyone.CastTargetIf(S.RayofFrost, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost cleave 8"; end
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
  -- blizzard,if=active_enemies>=2&talent.ice_caller&talent.freezing_rain&(!talent.splintering_cold&!talent.ray_of_frost|buff.freezing_rain.up|active_enemies>=3)
  if S.Blizzard:IsCastable() and (EnemiesCount16ySplash >= 2 and S.IceCaller:IsAvailable() and S.FreezingRain:IsAvailable() and (not S.SplinteringCold:IsAvailable() and not S.RayofFrost:IsAvailable() or Player:BuffUp(S.FreezingRainBuff) or EnemiesCount16ySplash >= 3)) then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard cleave 16"; end
  end
  -- shifting_power,if=cooldown.frozen_orb.remains>10&(!talent.comet_storm|cooldown.comet_storm.remains>10)&(!talent.ray_of_frost|cooldown.ray_of_frost.remains>10)|cooldown.icy_veins.remains<20
  if S.ShiftingPower:IsCastable() and (S.FrozenOrb:CooldownRemains() > 10 and (not S.CometStorm:IsAvailable() or S.CometStorm:CooldownRemains() > 10) and (not S.RayofFrost:IsAvailable() or S.RayofFrost:CooldownRemains() > 10) or S.IcyVeins:CooldownRemains() < 20) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power cleave 18"; end
  end
  -- glacial_spike,if=buff.icicles.react=5
  if S.GlacialSpike:IsReady() and (Icicles == 5) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike cleave 20"; end
  end
  -- ice_lance,target_if=max:debuff.winters_chill.stack,if=buff.fingers_of_frost.react&!prev_gcd.1.glacial_spike|remaining_winters_chill
  if S.IceLance:IsReady() and (Player:BuffUpP(S.FingersofFrostBuff) and not Player:PrevGCDP(1, S.GlacialSpike) or RemainingWintersChill > 0) then
    if Everyone.CastTargetIf(S.IceLance, Enemies16ySplash, "max", EvaluateTargetIfFilterWCStacks, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance cleave 22"; end
  end
  -- ice_nova,if=active_enemies>=4
  if S.IceNova:IsCastable() and (EnemiesCount16ySplash >= 4) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova cleave 24"; end
  end
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt cleave 26"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
  end
end

local function ST()
  -- comet_storm,if=prev_gcd.1.flurry|prev_gcd.1.cone_of_cold
  if S.CometStorm:IsCastable() and (Player:PrevGCDP(1, S.Flurry) or Player:PrevGCDP(1, S.ConeofCold)) then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single 2"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&((prev_gcd.1.frostbolt&buff.icicles.react>=3|prev_gcd.1.frostbolt&buff.brain_freeze.react)|prev_gcd.1.glacial_spike|talent.glacial_spike&buff.icicles.react=4&!buff.fingers_of_frost.react)
  if S.Flurry:IsCastable() and (RemainingWintersChill == 0 and Target:DebuffDown(S.WintersChillDebuff) and ((Player:PrevGCDP(1, S.Frostbolt) and Icicles >= 3 or Player:PrevGCDP(1, S.Frostbolt) and Player:BuffUp(S.BrainFreezeBuff)) or Player:PrevGCDP(1, S.GlacialSpike) or S.GlacialSpike:IsAvailable() and Icicles == 4 and Player:BuffDown(S.FingersofFrostBuff))) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single 4"; end
  end
  -- ice_lance,if=talent.glacial_spike&debuff.winters_chill.down&buff.icicles.react=4&buff.fingers_of_frost.react
  if S.IceLance:IsReady() and (S.GlacialSpike:IsAvailable() and RemainingWintersChill == 0 and Icicles == 4 and Player:BuffUp(S.FingersofFrostBuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 6"; end
  end
  -- ray_of_frost,if=remaining_winters_chill=1
  if S.RayofFrost:IsCastable() and (RemainingWintersChill == 1) then
    if Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single 8"; end
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
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single 16"; end
  end
  -- shifting_power,if=cooldown.frozen_orb.remains>10&(!talent.comet_storm|cooldown.comet_storm.remains>10)&(!talent.ray_of_frost|cooldown.ray_of_frost.remains>10)|cooldown.icy_veins.remains<20
  if S.ShiftingPower:IsCastable() and (S.FrozenOrb:CooldownRemains() > 10 and (not S.CometStorm:IsAvailable() or S.CometStorm:CooldownRemains() > 10) and (not S.RayofFrost:IsAvailable() or S.RayofFrost:CooldownRemains() > 10) or S.IcyVeins:CooldownRemains() < 20) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power single 18"; end
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
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt single 26"; end
  end
  -- call_action_list,name=movement
  if Player:IsMoving() then
    local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
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
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cds
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=aoe,if=active_enemies>=7&!set_bonus.tier30_2pc|active_enemies>=3&talent.ice_caller
    if AoEON() and (EnemiesCount16ySplash >= 7 and not Player:HasTier(30, 2) or EnemiesCount16ySplash >= 3 and S.IceCaller:IsAvailable()) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool for Aoe()"; end
    end
    -- run_action_list,name=cleave,if=active_enemies=2
    if AoEON() and EnemiesCount16ySplash == 2 then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool for Cleave()"; end
    end
    -- run_action_list,name=st
    local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "pool for ST()"; end
  end
end

local function Init()
  S.WintersChillDebuff:RegisterAuraTracking()

  HR.Print("Frost Mage rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(64, APL, Init)
