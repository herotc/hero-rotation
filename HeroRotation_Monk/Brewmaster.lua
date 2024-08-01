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

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Monk = HR.Commons.Monk
local Settings = {
  General     = HR.GUISettings.General,
  Commons     = HR.GUISettings.APL.Monk.Commons,
  CommonsDS   = HR.GUISettings.APL.Monk.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Monk.CommonsOGCD,
  Brewmaster  = HR.GUISettings.APL.Monk.Brewmaster
}

--- ===== Rotation Variables =====
local Enemies5y
local EnemiesCount5
local IsTanking

--- ===== Stun Interrupts List =====
local Stuns = {
  { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end },
  { S.Paralysis, "Cast Paralysis (Stun)", function () return true end },
}

--- ===== Helper Functions =====
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

  -- Purify if about to cap charges and we have Light Stagger
  if S.PurifyingBrew:ChargesFractional() >= 1.8 and Player:DebuffUp(S.LightStagger) then
    return true
  end

  -- Purify if we're at Heavy or Moderate Stagger
  if S.PurifyingBrew:Charges() >= 1 and (Player:DebuffUp(S.HeavyStagger) or Player:DebuffUp(S.ModerateStagger)) then
    return true
  end

  -- Otherwise, don't Purify
  return false
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  -- Note: Not adding potion, as they're not needed pre-combat any longer
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst precombat 2"; end
  end
  -- Manually added opener
  if S.KegSmash:IsCastable() then 
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash precombat 4"; end
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
    local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
    local IsTrinket = ItemSlot == 13 or ItemSlot == 14
    if not IsTrinket then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
    if (IsTrinket and Settings.Commons.Enabled.Trinkets) or (not IsTrinket and Settings.Commons.Enabled.Items) then
      if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
    end
  end
end

local function RaceActions()
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury race_actions 2"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking race_actions 4"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent race_actions 6"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "lights_judgment race_actions 8"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood race_actions 10"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call race_actions 12"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks race_actions 14"; end
  end
end

--- ===== APL Main =====
local function APL()
  -- Unit Update
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  if AoEON() then
    EnemiesCount5 = #Enemies5y
  else
    EnemiesCount5 = 1
  end
  
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
    -- Manually added: spear_hand_strike,if=target.debuff.casting.react
    local ShouldReturn = Everyone.Interrupt(S.SpearHandStrike, Settings.CommonsDS.DisplayStyle.Interrupts, Stuns); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives
    if IsTanking then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- expel_harm,if=buff.gift_of_the_ox.stack>4
    if S.ExpelHarm:IsReady() and (S.ExpelHarm:Count() > 4) then
      if Cast(S.ExpelHarm, Settings.Brewmaster.GCDasOffGCD.ExpelHarm, nil, not Target:IsInRange(20)) then return "expel_harm main 2"; end
    end
    -- potion
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 4"; end
      end
    end
    -- call_action_list,name=race_actions
    if CDsON() then
      local ShouldReturn = RaceActions(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=item_actions
    if Settings.Commons.Enabled.Items or Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = ItemActions(); if ShouldReturn then return ShouldReturn; end
    end
    -- black_ox_brew,if=energy<40
    if S.BlackOxBrew:IsCastable() and (Player:Energy() < 40) then
      if Cast(S.BlackOxBrew, Settings.Brewmaster.GCDasOffGCD.BlackOxBrew) then return "black_ox_brew main 6"; end
    end
    -- celestial_brew,if=buff.aspect_of_harmony_accumulator.value>0.98*health.max|(target.time_to_die<20&target.time_to_die>14&buff.aspect_of_harmony_accumulator.value>0.2*health.max)
    -- Note: Handled in Defensives.
    -- blackout_kick
    if S.BlackoutKick:IsReady() then
      if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick main 8"; end
    end
    -- chi_burst
    if S.ChiBurst:IsCastable() then
      if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst main 10"; end
    end
    -- weapons_of_order
    if S.WeaponsofOrder:IsReady() then
      if Cast(S.WeaponsofOrder) then return "weapons_of_order main 12"; end
    end
    -- rising_sun_kick,if=!talent.fluidity_of_motion.enabled
    if S.RisingSunKick:IsReady() and (not S.FluidityofMotion:IsAvailable()) then
      if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick main 14"; end
    end
    -- tiger_palm,if=buff.blackout_combo.up
    if S.TigerPalm:IsCastable() and (Player:BuffUp(S.BlackoutComboBuff)) then
      if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm main 16"; end
    end
    -- rising_sun_kick,if=talent.fluidity_of_motion.enabled
    if S.RisingSunKick:IsReady() and (S.FluidityofMotion:IsAvailable()) then
      if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick main 18"; end
    end
    -- purifying_brew,if=buff.blackout_combo.down
    if S.PurifyingBrew:IsCastable() and ShouldPurify() and (Player:BuffDown(S.BlackoutComboBuff)) then
      if Cast(S.PurifyingBrew, nil, Settings.Brewmaster.DisplayStyle.Purify) then return "purifying_brew main 20"; end
    end
    -- breath_of_fire,if=buff.charred_passions.down
    if S.BreathofFire:IsCastable() and (Player:BuffDown(S.CharredPassionsBuff)) then
      if Cast(S.BreathofFire, Settings.Brewmaster.GCDasOffGCD.BreathOfFire, nil, not Target:IsInMeleeRange(12)) then return "breath_of_fire main 22"; end
    end
    -- exploding_keg
    if S.ExplodingKeg:IsCastable() then
      if Cast(S.ExplodingKeg, nil, nil, not Target:IsInRange(40)) then return "exploding_keg main 24"; end
    end
    -- keg_smash
    if S.KegSmash:IsReady() then
      if Cast(S.KegSmash, nil, nil, not Target:IsInRange(15)) then return "keg_smash main 26"; end
    end
    -- rushing_jade_wind
    if S.RushingJadeWind:IsReady() then
      if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind main 28"; end
    end
    -- invoke_niuzao
    if S.InvokeNiuzao:IsCastable() then
      if Cast(S.InvokeNiuzao, Settings.Brewmaster.GCDasOffGCD.InvokeNiuzaoTheBlackOx) then return "invoke_niuzao main 30"; end
    end
    -- tiger_palm
    if S.TigerPalm:IsReady() then
      if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm main 32"; end
    end
    -- spinning_crane_kick
    if S.SpinningCraneKick:IsReady() then
      if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick main 34"; end
    end
    -- Manually added Pool filler
    if Cast(S.PoolEnergy) then return "Pool Energy"; end
  end
end

local function Init()
  HR.Print("Brewmaster Monk rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(268, APL, Init)
