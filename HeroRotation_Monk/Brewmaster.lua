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
local CastAnnotated = HR.CastAnnotated
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
  Brewmaster  = HR.GUISettings.APL.Monk.Brewmaster,
  BrMDS       = HR.GUISettings.APL.Monk.BrMDS,
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
  -- snapshot_stats
  -- potion
  -- Note: Not adding potion, as they're not needed pre-combat any longer
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, Settings.CommonsOGCD.GCDasOffGCD.ChiBurst, nil, not Target:IsInRange(40)) then return "chi_burst precombat 2"; end
  end
  -- Manually added opener
  if S.KegSmash:IsCastable() then 
    if Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "keg_smash precombat 4"; end
  end
end

local function Defensives()
  if S.CelestialBrew:IsCastable() and (Player:BuffDown(S.BlackoutComboBuff) and Player:IncomingDamageTaken(1999) > (UnitHealthMax("player") * 0.1 + Player:StaggerLastTickDamage(4)) and Player:BuffStack(S.ElusiveBrawlerBuff) < 2) then
    if Cast(S.CelestialBrew, nil, Settings.BrMDS.DisplayStyle.CelestialBrew) then return "Celestial Brew"; end
  end
  -- Modified code (include stagger damage, but remove buff checks):
  -- Incoming damage over 2 seconds exceeds 15% max health + recent stagger tick damage
  if S.CelestialInfusion:IsCastable() and Player:BuffDown(S.CelestialInfusion) and Player:IncomingDamageTaken(1999) > (UnitHealthMax("player") * 0.15 + Player:StaggerLastTickDamage(4)) then
    if Cast(S.CelestialInfusion, nil, Settings.BrMDS.DisplayStyle.CelestialInfusion) then return "Celestial Infusion"; end
  end
  if S.PurifyingBrew:IsCastable() and ShouldPurify() then
    if Cast(S.PurifyingBrew, nil, Settings.BrMDS.DisplayStyle.PurifyingBrew) then return "Purifying Brew (Capping Charges)"; end
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
  if S.DampenHarm:IsCastable() and Player:BuffDown(S.FortifyingBrewBuff) and Player:HealthPercentage() <= Settings.Brewmaster.DampenHarmHP then
    if Cast(S.DampenHarm, nil, Settings.BrMDS.DisplayStyle.DampenHarm) then return "Dampen Harm"; end
  end
  if S.FortifyingBrew:IsCastable() and Player:BuffDown(S.DampenHarmBuff) and Player:HealthPercentage() <= Settings.Brewmaster.FortifyingBrewHP then
    if Cast(S.FortifyingBrew, nil, Settings.BrMDS.DisplayStyle.FortifyingBrew) then return "Fortifying Brew"; end
  end
  if S.Vivify:IsReady() and Player:BuffUp(S.VivaciousVivicationBuff) and Player:HealthPercentage() <= Settings.Brewmaster.VivifyHP then
    if Cast(S.Vivify, nil, Settings.CommonsDS.DisplayStyle.Vivify) then return "Vivify"; end
  end
end

local function ItemActions()
  -- use_item,name=tome_of_lights_devotion,if=buff.inner_resilience.up
  if I.TomeofLightsDevotion:IsEquippedAndReady() and (Player:BuffUp(S.InnerResilienceBuff)) then
    if Cast(I.TomeofLightsDevotion, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "tome_of_lights_devotion item_actions 2"; end
  end
  -- use_item,name=unyielding_netherprism,if=buff.weapons_of_order.up&debuff.weapons_of_order_debuff.stack=4
  -- use_item,name=unyielding_netherprism,if=!talent.weapons_of_order.enabled
  if I.UnyieldingNetherprism:IsEquippedAndReady() and (Player:BuffUp(S.WeaponsofOrderBuff) and Target:DebuffStack(S.WeaponsofOrderDebuff) == 4 or not S.WeaponsofOrder:IsAvailable()) then
    if Cast(I.UnyieldingNetherprism, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "unyielding_netherprism item_actions 4"; end
  end
  -- use_item,name=lily_of_the_eternal_weave,if=buff.weapons_of_order.up&debuff.weapons_of_order_debuff.stack=4
  -- use_item,name=lily_of_the_eternal_weave,if=!talent.weapons_of_order.enabled
  if I.LilyoftheEternalWeave:IsEquippedAndReady() and (Player:BuffUp(S.WeaponsofOrderBuff) and Target:DebuffStack(S.WeaponsofOrderDebuff) == 4 or not S.WeaponsofOrder:IsAvailable()) then
    if Cast(I.LilyoftheEternalWeave, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "lily_of_the_eternal_weave item_actions 6"; end
  end
  -- use_item,name=signet_of_the_priory,if=buff.weapons_of_order.up&debuff.weapons_of_order_debuff.stack=4
  -- use_item,name=signet_of_the_priory,if=!talent.weapons_of_order.enabled
  if I.SignetofthePriory:IsEquippedAndReady() and (Player:BuffUp(S.WeaponsofOrderBuff) and Target:DebuffStack(S.WeaponsofOrderDebuff) == 4 or not S.WeaponsofOrder:IsAvailable()) then
    if Cast(I.SignetofthePriory, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "signet_of_the_priory item_actions 8"; end
  end
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
    -- potion
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
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
    -- black_ox_brew,if=energy<40&(!talent.aspect_of_harmony.enabled|cooldown.celestial_brew.charges_fractional<1)
    if S.BlackOxBrew:IsCastable() and (Player:Energy() < 40 and (not S.AspectofHarmony:IsAvailable() or S.CelestialBrew:ChargesFractional() < 1)) then
      if Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return "black_ox_brew main 4"; end
    end
    -- celestial_brew,if=(buff.aspect_of_harmony_accumulator.value>0.3*health.max&buff.weapons_of_order.up&!dot.aspect_of_harmony_damage.ticking)
    -- celestial_brew,if=(buff.aspect_of_harmony_accumulator.value>0.3*health.max&!talent.weapons_of_order.enabled&!dot.aspect_of_harmony_damage.ticking)
    -- celestial_brew,if=(target.time_to_die<20&target.time_to_die>14&buff.aspect_of_harmony_accumulator.value>0.2*health.max)
    -- celestial_brew,if=(buff.aspect_of_harmony_accumulator.value>0.3*health.max&cooldown.weapons_of_order.remains>20&!dot.aspect_of_harmony_damage.ticking)
    -- celestial_brew,if=!buff.blackout_combo.up&(cooldown.celestial_brew.charges_fractional>1.8|(cooldown.celestial_brew.charges_fractional>1.2&cooldown.black_ox_brew.up))
    -- Note: Handled in Defensives for now. TODO: Handle Aspect of Harmony.
    -- blackout_kick
    if S.BlackoutKick:IsReady() then
      if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick main 6"; end
    end
    -- chi_burst,if=!talent.aspect_of_harmony.enabled|buff.balanced_stratagem_magic.stack>3
    if S.ChiBurst:IsCastable() and (not S.AspectofHarmony:IsAvailable() or Player:BuffStack(S.BalancedStratagemMagic) > 3) then
      if Cast(S.ChiBurst, Settings.CommonsOGCD.GCDasOffGCD.ChiBurst, nil, not Target:IsInRange(40)) then return "chi_burst main 8"; end
    end
    -- weapons_of_order
    if S.WeaponsofOrder:IsReady() then
      if Cast(S.WeaponsofOrder, Settings.CommonsDS.DisplayStyle.WeaponsOfOrder) then return "weapons_of_order main 10"; end
    end
    -- invoke_niuzao,if=!talent.call_to_arms.enabled
    if S.InvokeNiuzao:IsCastable() and (not S.CalltoArms:IsAvailable()) then
      if Cast(S.InvokeNiuzao, Settings.Brewmaster.GCDasOffGCD.InvokeNiuzaoTheBlackOx) then return "invoke_niuzao main 12"; end
    end
    -- invoke_niuzao,if=talent.call_to_arms.enabled&buff.call_to_arms_invoke_niuzao.down&buff.weapons_of_order.remains<16
    if S.InvokeNiuzao:IsCastable() and (S.CalltoArms:IsAvailable() and Player:BuffDown(S.CalltoArmsInvokeNiuzaoBuff) and Player:BuffRemains(S.WeaponsofOrderBuff) < 16) then
      if Cast(S.InvokeNiuzao, Settings.Brewmaster.GCDasOffGCD.InvokeNiuzaoTheBlackOx) then return "invoke_niuzao main 14"; end
    end
    -- rising_sun_kick,if=!talent.fluidity_of_motion.enabled
    if S.RisingSunKick:IsReady() and (not S.FluidityofMotion:IsAvailable()) then
      if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick main 16"; end
    end
    -- keg_smash,if=buff.weapons_of_order.up&(debuff.weapons_of_order_debuff.remains<1.8|debuff.weapons_of_order_debuff.stack<3-buff.blackout_combo.up|(buff.weapons_of_order.remains<3-buff.blackout_combo.up&buff.weapons_of_order.remains<1+cooldown.rising_sun_kick.remains))
    if S.KegSmash:IsReady() and (Player:BuffUp(S.WeaponsofOrderBuff) and (Target:DebuffRemains(S.WeaponsofOrderDebuff) < 1.8 or Target:DebuffStack(S.WeaponsofOrderDebuff) < 3 - num(Player:BuffUp(S.BlackoutComboBuff)) or (Player:BuffRemains(S.WeaponsofOrderBuff) < 3 - num(Player:BuffUp(S.BlackoutComboBuff)) and Player:BuffRemains(S.WeaponsofOrderBuff) < 1 + S.RisingSunKick:CooldownRemains()))) then
      if Cast(S.KegSmash, nil, nil, not Target:IsInRange(15)) then return "keg_smash main 18"; end
    end
    -- tiger_palm,if=buff.blackout_combo.up
    if S.TigerPalm:IsCastable() and (Player:BuffUp(S.BlackoutComboBuff)) then
      if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm main 20"; end
    end
    -- keg_smash,if=talent.scalding_brew.enabled
    if S.KegSmash:IsReady() and (S.ScaldingBrew:IsAvailable()) then
      if Cast(S.KegSmash, nil, nil, not Target:IsInRange(15)) then return "keg_smash main 22"; end
    end
    -- spinning_crane_kick,if=talent.charred_passions.enabled&talent.scalding_brew.enabled&buff.charred_passions.up&buff.charred_passions.remains<3&dot.breath_of_fire.remains<9&active_enemies>4
    if S.SpinningCraneKick:IsReady() and (S.CharredPassions:IsAvailable() and S.ScaldingBrew:IsAvailable() and Player:BuffUp(S.CharredPassionsBuff) and Player:BuffRemains(S.CharredPassionsBuff) < 3 and Target:DebuffRemains(S.BreathofFireDotDebuff) < 9 and EnemiesCount5 > 4) then
      if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick main 24"; end
    end
    -- rising_sun_kick,if=talent.fluidity_of_motion.enabled
    if S.RisingSunKick:IsReady() and (S.FluidityofMotion:IsAvailable()) then
      if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick main 26"; end
    end
    if S.PurifyingBrew:IsCastable() and ShouldPurify() and (Player:BuffDown(S.BlackoutComboBuff)) and (
      -- purifying_brew,if=buff.blackout_combo.down&!(talent.call_to_arms.enabled|talent.invoke_niuzao_the_black_ox.enabled)
      (not (S.CalltoArms:IsAvailable() or S.InvokeNiuzao:IsAvailable())) or
      -- purifying_brew,if=buff.blackout_combo.down&(talent.call_to_arms.enabled|talent.invoke_niuzao_the_black_ox.enabled)&(buff.invoke_niuzao_the_black_ox.up|buff.call_to_arms_invoke_niuzao.up)
      ((S.CalltoArms:IsAvailable() or S.InvokeNiuzao:IsAvailable()) and (Player:BuffUp(S.InvokeNiuzaoBuff) or Player:BuffUp(S.CalltoArmsInvokeNiuzaoBuff))) or
      -- purifying_brew,if=buff.blackout_combo.down&(talent.call_to_arms.enabled|talent.invoke_niuzao_the_black_ox.enabled)&cooldown.weapons_of_order.remains>10&cooldown.invoke_niuzao_the_black_ox.remains>10
      ((S.CalltoArms:IsAvailable() or S.InvokeNiuzao:IsAvailable()) and S.WeaponsofOrder:CooldownRemains() > 10 and S.InvokeNiuzao:CooldownRemains() > 10)
    ) then
      if Cast(S.PurifyingBrew, nil, Settings.BrMDS.DisplayStyle.PurifyingBrew) then return "purifying_brew main 28"; end
    end
    -- breath_of_fire,if=(buff.charred_passions.down&(!talent.scalding_brew.enabled|active_enemies<5))|!talent.charred_passions.enabled|(dot.breath_of_fire.remains<3&talent.scalding_brew.enabled)
    if S.BreathofFire:IsCastable() and ((Player:BuffDown(S.CharredPassionsBuff) and (not S.ScaldingBrew:IsAvailable() or EnemiesCount5 < 5)) or not S.CharredPassions:IsAvailable() or (Target:DebuffRemains(S.BreathofFireDotDebuff) < 3 and S.ScaldingBrew:IsAvailable())) then
      if Cast(S.BreathofFire, Settings.Brewmaster.GCDasOffGCD.BreathOfFire, nil, not Target:IsInMeleeRange(12)) then return "breath_of_fire main 30"; end
    end
    -- exploding_keg,if=!talent.rushing_jade_wind.enabled|buff.rushing_jade_wind.up
    if S.ExplodingKeg:IsCastable() and (not S.RushingJadeWind:IsAvailable() or Player:BuffUp(S.RushingJadeWindBuff)) then
      if Cast(S.ExplodingKeg, Settings.Brewmaster.GCDasOffGCD.ExplodingKeg, nil, not Target:IsInRange(40)) then return "exploding_keg main 32"; end
    end
    -- rushing_jade_wind,if=talent.aspect_of_harmony.enabled&((buff.rushing_jade_wind.remains<2.5&buff.rushing_jade_wind.up)|!buff.rushing_jade_wind.up)
    if S.RushingJadeWind:IsReady() and (S.AspectofHarmony:IsAvailable() and ((Player:BuffRemains(S.RushingJadeWindBuff) < 2.5 and Player:BuffUp(S.RushingJadeWindBuff)) or Player:BuffDown(S.RushingJadeWindBuff))) then
      if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind main 34"; end
    end
    -- keg_smash
    if S.KegSmash:IsReady() then
      if Cast(S.KegSmash, nil, nil, not Target:IsInRange(15)) then return "keg_smash main 36"; end
    end
    -- rushing_jade_wind,if=!talent.aspect_of_harmony.enabled&((buff.rushing_jade_wind.remains<2.5&buff.rushing_jade_wind.up)|!buff.rushing_jade_wind.up)
    if S.RushingJadeWind:IsReady() and (not S.AspectofHarmony:IsAvailable() and ((Player:BuffRemains(S.RushingJadeWindBuff) < 2.5 and Player:BuffUp(S.RushingJadeWindBuff)) or Player:BuffDown(S.RushingJadeWindBuff))) then
      if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind main 38"; end
    end
    -- tiger_palm,if=energy>40-cooldown.keg_smash.remains*energy.regen
    if S.TigerPalm:IsReady() and (Player:Energy() > 40 - S.KegSmash:CooldownRemains() * Player:EnergyRegen()) then
      if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm main 40"; end
    end
    -- spinning_crane_kick,if=energy>40-cooldown.keg_smash.remains*energy.regen
    if S.SpinningCraneKick:IsReady() and (Player:Energy() > 40 - S.KegSmash:CooldownRemains() * Player:EnergyRegen()) then
      if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick main 42"; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Brewmaster Monk rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(268, APL, Init)
