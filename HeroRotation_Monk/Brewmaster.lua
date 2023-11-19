--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC        = HeroDBC.DBC
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
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Cast       = HR.Cast
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- Lua
-- WoW API
local UnitHealthMax = UnitHealthMax
local GetTime       = GetTime
local GetSpellBonusDamage = GetSpellBonusDamage

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
local S = Spell.Monk.Brewmaster
local I = Item.Monk.Brewmaster

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.TrinketName:ID(),
}

-- Rotation Var
local Enemies5y
local Enemies8y
local EnemiesCount5
local IsTanking

-- Weapon checks
local MainHandLink = GetInventoryItemLink("player", 16) or ""
local Using2H = IsEquippedItemType("Two-Hand")

HL:RegisterForEvent(function()
  MainHandLink = GetInventoryItemLink("player", 16) or ""
  Using2H = IsEquippedItemType("Two-Hand")
end, "PLAYER_EQUIPMENT_CHANGED")

-- Interrupts
local Stuns = {
  { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end },
  { S.Paralysis, "Cast Paralysis (Stun)", function () return true end },
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Monk = HR.Commons.Monk
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Brewmaster = HR.GUISettings.APL.Monk.Brewmaster
}

local function ShouldPurify()
  local StaggerFull = Player:StaggerFull() or 0
  -- if there's no stagger, just exit so we don't have to calculate anything
  if StaggerFull == 0 then return false end
  local StaggerCurrent = 0
  local StaggerSpell = nil
  if Player:BuffUp(S.LightStagger) then
    StaggerSpell = S.LightStagger
  elseif Player:BuffUp(S.ModerateStagger) then
    StaggerSpell = S.ModerateStagger
  elseif Player:BuffUp(S.HeavyStagger) then
    StaggerSpell = S.HeavyStagger
  end
  if StaggerSpell then
    local StaggerTable = Player:DebuffInfo(StaggerSpell, false, true)
    StaggerCurrent = StaggerTable.points[2]
  end

  -- Purify if about to cap charges and we have Stagger damage
  if (S.PurifyingBrew:ChargesFractional() >= 1.8 and (Player:DebuffUp(S.HeavyStagger) or Player:DebuffUp(S.ModerateStagger) or Player:DebuffUp(S.LightStagger))) then
    return true
  end

  -- Otherwise, don't Purify
  return false
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  -- Note: Not adding potion, as they're not needed pre-combat any longer
  -- chi_burst,if=talent.chi_burst.enabled
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst precombat 2"; end
  end
  -- chi_wave,if=talent.chi_wave.enabled
  if S.ChiWave:IsCastable() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave precombat 4"; end
  end
  -- Manually added opener
  if S.KegSmash:IsCastable() then 
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash precombat 6"; end
  end
end

local function Defensives()
  if S.CelestialBrew:IsCastable() and (Player:BuffDown(S.BlackoutComboBuff) and Player:IncomingDamageTaken(1999) > (UnitHealthMax("player") * 0.1 + Player:StaggerLastTickDamage(4)) and Player:BuffStack(S.ElusiveBrawlerBuff) < 2) then
    if Cast(S.CelestialBrew, nil, Settings.Brewmaster.DisplayStyle.CelestialBrew) then return "Celestial Brew"; end
  end
  if S.PurifyingBrew:IsCastable() and ShouldPurify() then
    if Cast(S.PurifyingBrew, nil, Settings.Brewmaster.DisplayStyle.Purify) then return "Purifying Brew (Capping Charges)"; end
  end
  if S.ExpelHarm:IsReady() and Player:HealthPercentage() <= Settings.Brewmaster.ExpelHarmHP then
    local ExpelHarmMod = (S.StrengthofSpirit:IsAvailable()) and (1 + (1 - Player:HealthPercentage() / 100) * 100) or 1
    local HealingSphereValue = Player:AttackPowerDamageMod() * 3
    local ExpelHarmHeal = (GetSpellBonusDamage(4) * 1.2 * ExpelHarmMod) + (S.ExpelHarm:Count() * HealingSphereValue)
    local MissingHP = Player:MaxHealth() - Player:Health()
    -- Allow us to "waste" 10% of the Expel Harm heal amount.
    if MissingHP > ExpelHarmHeal * 0.9 or Player:HealthPercentage() <= Settings.Brewmaster.ExpelHarmHP / 2 then
      if Cast(S.ExpelHarm, Settings.Brewmaster.GCDasOffGCD.ExpelHarm) then return "Expel Harm (defensives)"; end
    end
  end
  if S.DampenHarm:IsCastable() and Player:BuffDown(S.FortifyingBrewBuff) and Player:HealthPercentage() <= 35 then
    if Cast(S.DampenHarm, nil, Settings.Brewmaster.DisplayStyle.DampenHarm) then return "Dampen Harm"; end
  end
  if S.FortifyingBrew:IsCastable() and Player:BuffDown(S.DampenHarmBuff) and Player:HealthPercentage() <= 25 then
    if Cast(S.FortifyingBrew, nil, Settings.Brewmaster.DisplayStyle.FortifyingBrew) then return "Fortifying Brew"; end
  end
end

local function ItemActions()
  -- use_items
  local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
  if ItemToUse then
    local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
    local IsTrinket = ItemSlot == 13 or ItemSlot == 14
    if not IsTrinket then DisplayStyle = Settings.Commons.DisplayStyle.Items end
    if (IsTrinket and Settings.Commons.Enabled.Trinkets) or (not IsTrinket and Settings.Commons.Enabled.Items) then
      if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
    end
  end
end

local function RaceActions()
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury race_actions 2"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking race_actions 4"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "lights_judgment race_actions 6"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood race_actions 8"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call race_actions 10"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks race_actions 12"; end
  end
end

local function RotationPTA()
  -- invoke_niuzao_the_black_ox
  if CDsON() and S.InvokeNiuzaoTheBlackOx:IsCastable() then
    if Cast(S.InvokeNiuzaoTheBlackOx, Settings.Brewmaster.GCDasOffGCD.InvokeNiuzaoTheBlackOx, nil, not Target:IsInRange(40)) then return "invoke_niuzao_the_black_ox rotation_pta 2"; end
  end
  if S.RisingSunKick:IsCastable() and (
    -- rising_sun_kick,if=buff.press_the_advantage.stack<(7+main_hand.2h)
    (Player:BuffStack(S.PresstheAdvantageBuff) < (7 + num(Using2H))) or
    -- rising_sun_kick,if=buff.press_the_advantage.stack>9&active_enemies<=3&(buff.blackout_combo.up|!talent.blackout_combo.enabled)
    (Player:BuffStack(S.PresstheAdvantageBuff) > 9 and EnemiesCount5 <= 3 and (Player:BuffUp(S.BlackoutComboBuff) or not S.BlackoutCombo:IsAvailable()))
  ) then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick rotation_pta 4"; end
  end
  -- keg_smash,if=(buff.press_the_advantage.stack>9)&active_enemies>3
  if S.KegSmash:IsReady() and (Player:BuffStack(S.PresstheAdvantageBuff) > 9 and EnemiesCount5 > 3) then
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash rotation_pta 6"; end
  end
  -- spinning_crane_kick,if=active_enemies>5&buff.exploding_keg.up&buff.charred_passions.up
  if S.SpinningCraneKick:IsReady() and (EnemiesCount5 > 5 and Player:BuffUp(S.ExplodingKeg) and Player:BuffUp(S.CharredPassionsBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick rotation_pta 8"; end
  end
  -- blackout_kick
  if S.BlackoutKick:IsCastable() then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick rotation_pta 10"; end
  end
  -- purifying_brew,if=(!buff.blackout_combo.up)
  if S.PurifyingBrew:IsCastable() and Player:StaggerFull() > 0 and (Player:BuffDown(S.BlackoutComboBuff)) then
    if Cast(S.PurifyingBrew, nil, Settings.Brewmaster.DisplayStyle.Purify) then return "purifying_brew rotation_pta 12"; end
  end
  -- black_ox_brew,if=energy+energy.regen<=40
  if CDsON() and S.BlackOxBrew:IsCastable() and (Player:Energy() + Player:EnergyRegen() <= 40) then
    if Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return "black_ox_brew rotation_pta 14"; end
  end
  -- breath_of_fire,if=buff.charred_passions.remains<cooldown.blackout_kick.remains&(buff.blackout_combo.up|!talent.blackout_combo.enabled)
  if S.BreathofFire:IsCastable() and (Player:BuffRemains(S.CharredPassionsBuff) < S.BlackoutKick:CooldownRemains() and (Player:BuffUp(S.BlackoutComboBuff) or not S.BlackoutCombo:IsAvailable())) then
    if Cast(S.BreathofFire, Settings.Commons.GCDasOffGCD.BreathOfFire, nil, not Target:IsInMeleeRange(12)) then return "breath_of_fire rotation_pta 16"; end
  end
  -- summon_white_tiger_statue
  if CDsON() and S.SummonWhiteTigerStatue:IsCastable() then
    if Cast(S.SummonWhiteTigerStatue, Settings.Brewmaster.GCDasOffGCD.SummonWhiteTigerStatue, nil, not Target:IsInRange(40)) then return "summon_white_tiger_statue rotation_pta 18"; end
  end
  -- bonedust_brew
  if S.BonedustBrew:IsCastable() then
    if Cast(S.BonedustBrew, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(40)) then return "bonedust_brew rotation_pta 20"; end
  end
  -- exploding_keg,if=((buff.bonedust_brew.up)|(cooldown.bonedust_brew.remains>=20))
  -- exploding_keg,if=(!talent.bonedust_brew.enabled)
  -- Note: Combining both lines.
  if S.ExplodingKeg:IsCastable() and (Player:BuffUp(S.BonedustBrewBuff) or S.BonedustBrew:CooldownRemains() >= 20 or not S.BonedustBrew:IsAvailable()) then
    if Cast(S.ExplodingKeg, Settings.Commons.GCDasOffGCD.ExplodingKeg, nil, not Target:IsInRange(40)) then return "exploding_keg rotation_pta 22"; end
  end
  -- breath_of_fire,if=(buff.blackout_combo.up|!talent.blackout_combo.enabled)
  if S.BreathofFire:IsCastable() and (Player:BuffUp(S.BlackoutComboBuff) or not S.BlackoutCombo:IsAvailable()) then
    if Cast(S.BreathofFire, Settings.Commons.GCDasOffGCD.BreathofFire, nil, not Target:IsInMeleeRange(12)) then return "breath_of_fire rotation_pta 24"; end
  end
  -- keg_smash,if=buff.press_the_advantage.stack<10
  if S.KegSmash:IsReady() and (Player:BuffStack(S.PresstheAdvantageBuff) < 10) then
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash rotation_pta 26"; end
  end
  -- rushing_jade_wind,if=talent.rushing_jade_wind.enabled
  if S.RushingJadeWind:IsCastable() then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind rotation_pta 28"; end
  end
  -- spinning_crane_kick,if=active_enemies>2
  -- spinning_crane_kick,if=(1.1>(time-action.melee_main_hand.last_used)*(1+spell_haste)-main_hand.2h)
  -- Note: Combining both lines.
  if S.SpinningCraneKick:IsReady() and (
    (EnemiesCount5 > 2) or
    (1.1 > (GetTime() - Player:PrevGCDTime()) * (1 + Player:SpellHaste()) - num(Using2H))
  ) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick rotation_pta 30"; end
  end
  -- expel_harm
  if S.ExpelHarm:IsReady() then
    if Cast(S.ExpelHarm, Settings.Brewmaster.GCDasOffGCD.ExpelHarm, nil, not Target:IsInMeleeRange(8)) then return "expel_harm rotation_pta 32"; end
  end
  -- chi_wave
  if S.ChiWave:IsCastable() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave rotation_pta 34"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst rotation_pta 36"; end
  end
end

local function RotationBOC()
  -- blackout_kick
  if S.BlackoutKick:IsCastable() then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick rotation_boc 2"; end
  end
  local RecentPurifiesBuff = S.PurifyingBrew:TimeSinceLastCast() < 6 and Monk.LastNiuzaoStomp < S.PurifyingBrew.LastCastTime
  -- purifying_brew,if=(buff.blackout_combo.down&(buff.recent_purifies.down|cooldown.purifying_brew.charges_fractional>(1+talent.improved_purifying_brew.enabled-0.1)))&talent.improved_invoke_niuzao_the_black_ox.enabled&(cooldown.weapons_of_order.remains>40|cooldown.weapons_of_order.remains<5)
  if S.PurifyingBrew:IsCastable() and Player:StaggerFull() > 0 and ((Player:BuffDown(S.BlackoutComboBuff) and (not RecentPurifiesBuff or S.PurifyingBrew:ChargesFractional() > (1 + num(S.ImprovedPurifyingBrew:IsAvailable()) - 0.1))) and S.ImprovedInvokeNiuzao:IsAvailable() and (S.WeaponsofOrder:CooldownRemains() > 40 or S.WeaponsofOrder:CooldownRemains() < 5)) then
    if Cast(S.PurifyingBrew, nil, Settings.Brewmaster.DisplayStyle.Purify) then return "purifying_brew rotation_boc 4"; end
  end
  -- weapons_of_order,if=(buff.recent_purifies.up)&talent.improved_invoke_niuzao_the_black_ox.enabled
  if CDsON() and S.WeaponsofOrder:IsCastable() and (RecentPurifiesBuff and S.ImprovedInvokeNiuzao:IsAvailable()) then
    if Cast(S.WeaponsofOrder, Settings.Brewmaster.GCDasOffGCD.WeaponsOfOrder) then return "weapons_of_order rotation_boc 6"; end
  end
  -- invoke_niuzao_the_black_ox,if=(buff.invoke_niuzao_the_black_ox.down&buff.recent_purifies.up&buff.weapons_of_order.remains<14)&talent.improved_invoke_niuzao_the_black_ox.enabled
  if CDsON() and S.InvokeNiuzaoTheBlackOx:IsCastable() and ((Player:BuffDown(S.InvokeNiuzaoTheBlackOx) and RecentPurifiesBuff and Player:BuffRemains(S.WeaponsofOrderBuff) < 14) and S.ImprovedInvokeNiuzao:IsAvailable()) then
    if Cast(S.InvokeNiuzaoTheBlackOx, Settings.Brewmaster.GCDasOffGCD.InvokeNiuzaoTheBlackOx, nil, not Target:IsInRange(40)) then return "invoke_niuzao_the_black_ox rotation_boc 8"; end
  end
  -- invoke_niuzao_the_black_ox,if=(debuff.weapons_of_order_debuff.stack>3)&!talent.improved_invoke_niuzao_the_black_ox.enabled
  if CDsON() and S.InvokeNiuzaoTheBlackOx:IsCastable() and (Target:DebuffStack(S.WeaponsofOrderDebuff) > 3 and not S.ImprovedInvokeNiuzao:IsAvailable()) then
    if Cast(S.InvokeNiuzaoTheBlackOx, Settings.Brewmaster.GCDasOffGCD.InvokeNiuzaoTheBlackOx, nil, not Target:IsInRange(40)) then return "invoke_niuzao_the_black_ox rotation_boc 10"; end
  end
  -- invoke_niuzao_the_black_ox,if=(!talent.weapons_of_order.enabled)
  if CDsON() and S.InvokeNiuzaoTheBlackOx:IsCastable() and (not S.WeaponsofOrder:IsAvailable()) then
    if Cast(S.InvokeNiuzaoTheBlackOx, Settings.Brewmaster.GCDasOffGCD.InvokeNiuzaoTheBlackOx, nil, not Target:IsInRange(40)) then return "invoke_niuzao_the_black_ox rotation_boc 12"; end
  end
  -- weapons_of_order,if=(talent.weapons_of_order.enabled)&!talent.improved_invoke_niuzao_the_black_ox.enabled
  if CDsON() and S.WeaponsofOrder:IsCastable() and (not S.ImprovedInvokeNiuzao:IsAvailable()) then
    if Cast(S.WeaponsofOrder, Settings.Brewmaster.GCDasOffGCD.WeaponsOfOrder) then return "weapons_of_order rotation_boc 14"; end
  end
  -- keg_smash,if=(time-action.weapons_of_order.last_used<2)
  if S.KegSmash:IsReady() and (S.WeaponsofOrder:TimeSinceLastCast() < 2) then
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash rotation_boc 16"; end
  end
  -- keg_smash,if=(buff.weapons_of_order.remains<gcd*2&buff.weapons_of_order.up)&!talent.improved_invoke_niuzao_the_black_ox.enabled
  if S.KegSmash:IsReady() and ((Player:BuffRemains(S.WeaponsofOrderBuff) < Player:GCD() * 2 and Player:BuffUp(S.WeaponsofOrderBuff)) and not S.ImprovedInvokeNiuzao:IsAvailable()) then
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash rotation_boc 18"; end
  end
  -- keg_smash,if=(buff.weapons_of_order.remains<gcd*2)&talent.improved_invoke_niuzao_the_black_ox.enabled
  if S.KegSmash:IsReady() and (Player:BuffRemains(S.WeaponsofOrderBuff) < Player:GCD() * 2 and S.ImprovedInvokeNiuzao:IsAvailable()) then
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash rotation_boc 20"; end
  end
  -- purifying_brew,if=(!buff.blackout_combo.up)&!talent.improved_invoke_niuzao_the_black_ox.enabled
  if S.PurifyingBrew:IsCastable() and Player:StaggerFull() > 0 and (Player:BuffDown(S.BlackoutComboBuff) and not S.ImprovedInvokeNiuzao:IsAvailable()) then
    if Cast(S.PurifyingBrew, nil, Settings.Brewmaster.DisplayStyle.Purify) then return "purifying_brew rotation_boc 22"; end
  end
  -- rising_sun_kick
  if S.RisingSunKick:IsCastable() then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick rotation_boc 24"; end
  end
  -- black_ox_brew,if=(energy+energy.regen<=40)
  if CDsON() and S.BlackOxBrew:IsCastable() and (Player:Energy() + Player:EnergyRegen() <= 40) then
    if Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return "black_ox_brew rotation_boc 26"; end
  end
  -- tiger_palm,if=(buff.blackout_combo.up&active_enemies=1)
  if S.TigerPalm:IsReady() and (Player:BuffUp(S.BlackoutComboBuff) and EnemiesCount5 == 1) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm rotation_boc 28"; end
  end
  -- breath_of_fire,if=(buff.charred_passions.remains<cooldown.blackout_kick.remains)
  if S.BreathofFire:IsCastable() and (Player:BuffRemains(S.CharredPassionsBuff) < S.BlackoutKick:CooldownRemains()) then
    if Cast(S.BreathofFire, Settings.Commons.GCDasOffGCD.BreathofFire, nil, not Target:IsInMeleeRange(12)) then return "breath_of_fire rotation_boc 30"; end
  end
  -- keg_smash,if=(buff.weapons_of_order.up&debuff.weapons_of_order_debuff.stack<=3)
  if S.KegSmash:IsReady() and (Player:BuffUp(S.WeaponsofOrderBuff) and Player:BuffStack(S.WeaponsofOrderBuff) <= 3) then
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash rotation_boc 32"; end
  end
  -- summon_white_tiger_statue,if=(debuff.weapons_of_order_debuff.stack>3)
  -- summon_white_tiger_statue,if=(!talent.weapons_of_order.enabled)
  -- Note: Combining both lines.
  if CDsON() and S.SummonWhiteTigerStatue:IsCastable() and (Target:DebuffStack(S.WeaponsofOrderDebuff) > 3 or not S.WeaponsofOrder:IsAvailable()) then
    if Cast(S.SummonWhiteTigerStatue, Settings.Brewmaster.GCDasOffGCD.SummonWhiteTigerStatue, nil, not Target:IsInRange(40)) then return "summon_white_tiger_statue rotation_boc 34"; end
  end
  -- bonedust_brew,if=(time<10&debuff.weapons_of_order_debuff.stack>3)|(time>10&talent.weapons_of_order.enabled)
  -- bonedust_brew,if=(!talent.weapons_of_order.enabled)
  -- Note: Combining both lines.
  if S.BonedustBrew:IsCastable() and ((CombatTime < 10 and Target:DebuffStack(S.WeaponsofOrderDebuff) > 3) or (CombatTime > 10 and S.WeaponsofOrder:IsAvailable()) or not S.WeaponsofOrder:IsAvailable()) then
    if Cast(S.BonedustBrew, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(40)) then return "bonedust_brew rotation_boc 36"; end
  end
  -- exploding_keg,if=(buff.bonedust_brew.up)
  -- exploding_keg,if=(cooldown.bonedust_brew.remains>=20)
  -- exploding_keg,if=(!talent.bonedust_brew.enabled)
  -- Note: Combining all three lines.
  if S.ExplodingKeg:IsCastable() and (Player:BuffUp(S.BonedustBrewBuff) or S.BonedustBrew:CooldownRemains() >= 20 or not S.BonedustBrew:IsAvailable()) then
    if Cast(S.ExplodingKeg, Settings.Commons.GCDasOffGCD.ExplodingKeg, nil, not Target:IsInRange(40)) then return "exploding_keg rotation_boc 38"; end
  end
  -- keg_smash
  if S.KegSmash:IsReady() then
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash rotation_boc 40"; end
  end
  -- rushing_jade_wind,if=talent.rushing_jade_wind.enabled
  if S.RushingJadeWind:IsCastable() then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind rotation_boc 42"; end
  end
  -- breath_of_fire
  if S.BreathofFire:IsCastable() then
    if Cast(S.BreathofFire, Settings.Commons.GCDasOffGCD.BreathofFire, nil, not Target:IsInMeleeRange(12)) then return "breath_of_fire rotation_boc 44"; end
  end
  -- tiger_palm,if=active_enemies=1&!talent.blackout_combo.enabled
  if S.TigerPalm:IsReady() and (EnemiesCount5 == 1 and not S.BlackoutCombo:IsAvailable()) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm rotation_boc 46"; end
  end
  -- spinning_crane_kick,if=active_enemies>1
  if S.SpinningCraneKick:IsReady() and (EnemiesCount5 > 1) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick rotation_boc 48"; end
  end
  -- expel_harm
  if S.ExpelHarm:IsReady() then
    if Cast(S.ExpelHarm, Settings.Brewmaster.GCDasOffGCD.ExpelHarm, nil, not Target:IsInMeleeRange(8)) then return "expel_harm rotation_boc 50"; end
  end
  -- chi_wave
  if S.ChiWave:IsCastable() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave rotation_boc 52"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst rotation_boc 54"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Unit Update
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  --Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  EnemiesCount5 = #Enemies5y -- AOE Toogle
  
  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies5y, false)
    end

    -- Are we tanking?
    IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

    -- Update CombatTime, which is used in many spell suggestions
    CombatTime = HL.CombatTime()
  end

  --- In Combat
  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- roll,if=movement.distance>5
    -- chi_torpedo,if=movement.distance>5
    -- Note: Not suggesting movement abilities
    -- spear_hand_strike,if=target.debuff.casting.react
    local ShouldReturn = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.Interrupts, Stuns); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives
    if IsTanking then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- potion
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    -- invoke_external_buff,name=power_infusion,if=buff.weapons_of_order.remains<=20&talent.weapons_of_order.enabled
    -- invoke_external_buff,name=power_infusion,if=!talent.weapons_of_order.enabled
    -- Note: Not handling external buffs
    -- call_action_list,name=item_actions
    if Settings.Commons.Enabled.Items or Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = ItemActions(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=race_actions
    if CDsON() then
      local ShouldReturn = RaceActions(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=rotation_pta,if=talent.press_the_advantage.enabled
    if S.PresstheAdvantage:IsAvailable() then
      local ShouldReturn = RotationPTA(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=rotation_boc,if=!talent.press_the_advantage.enabled
    if not S.PresstheAdvantage:IsAvailable() then
      local ShouldReturn = RotationBOC(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added Pool filler
    if Cast(S.PoolEnergy) then return "Pool Energy"; end
  end
end

local function Init()
  HR.Print("Brewmaster Monk rotation has been updated for patch 10.2.0.")
end

HR.SetAPL(268, APL, Init)
