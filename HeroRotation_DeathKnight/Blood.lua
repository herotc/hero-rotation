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
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local mathmin    = math.min
-- WoW API
local Delay       = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Blood
local I = Item.DeathKnight.Blood

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.Item:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  CommonsDS = HR.GUISettings.APL.DeathKnight.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.DeathKnight.CommonsOGCD,
  Blood = HR.GUISettings.APL.DeathKnight.Blood
}

--- ===== Rotation Variables =====
local VarDeathStrikeDumpAmt = S.ReapersMark:IsAvailable() and 50 or 65
local VarBoneShieldRefreshValue = S.ReapersMark:IsAvailable() and 9 or 12
local VarHeartStrikeRPDRW = 25 + num(S.Heartbreaker:IsAvailable()) * 2
local VarBoneShieldStacks
local IsTanking
local EnemiesMelee
local EnemiesMeleeCount
local HeartStrikeCount
local UnitsWithoutBloodPlague
local Ghoul = HL.GhoulTable

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Level, VarTrinket2Level
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.Level == 0 or T2.Level == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1ID = T1.ID
  VarTrinket2ID = T2.ID

  VarTrinket1Level = T1.Level
  VarTrinket2Level = T2.Level

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1BL = T1.Blacklisted
  VarTrinket2BL = T2.Blacklisted
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarDeathStrikeDumpAmt = S.ReapersMark:IsAvailable() and 50 or 65
  VarBoneShieldRefreshValue = S.ReapersMark:IsAvailable() and 9 or 12
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function UnitsWithoutBP(enemies)
  local WithoutBPCount = 0
  for _, CycleUnit in pairs(enemies) do
    if not CycleUnit:DebuffUp(S.BloodPlagueDebuff) then
      WithoutBPCount = WithoutBPCount + 1
    end
  end
  return WithoutBPCount
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: Openers
  if S.DeathsCaress:IsReady() then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress precombat 4"; end
  end
  if S.Marrowrend:IsReady() then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend precombat 6"; end
  end
end

local function Defensives()
  -- Rune Tap Emergency
  if S.RuneTap:IsReady() and IsTanking and Player:HealthPercentage() <= Settings.Blood.RuneTapThreshold and Player:Rune() >= 3 and S.RuneTap:Charges() >= 1 and Player:BuffDown(S.RuneTapBuff) then
    if Cast(S.RuneTap, Settings.Blood.OffGCDasOffGCD.RuneTap) then return "rune_tap defensives 2"; end
  end
  -- Active Mitigation
  if Player:ActiveMitigationNeeded() and S.Marrowrend:TimeSinceLastCast() > 2.5 and S.DeathStrike:TimeSinceLastCast() > 2.5 then
    if S.DeathStrike:IsReady() and Player:BuffStack(S.BoneShieldBuff) > 7 then
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 4"; end
    end
    if S.Marrowrend:IsReady() then
      if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend defensives 6"; end
    end
    if S.DeathStrike:IsReady() then
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 8"; end
    end
  end
  -- Icebound Fortitude
  if S.IceboundFortitude:IsCastable() and IsTanking and Player:HealthPercentage() <= Settings.Blood.IceboundFortitudeThreshold and Player:BuffDown(S.DancingRuneWeaponBuff) and Player:BuffDown(S.VampiricBloodBuff) then
    if Cast(S.IceboundFortitude, Settings.Blood.GCDasOffGCD.IceboundFortitude) then return "icebound_fortitude defensives 10"; end
  end
  -- Vampiric Blood
  if S.VampiricBlood:IsCastable() and IsTanking and Player:HealthPercentage() <= Settings.Blood.VampiricBloodThreshold and Player:BuffDown(S.DancingRuneWeaponBuff) and Player:BuffDown(S.IceboundFortitudeBuff) and Player:BuffDown(S.VampiricBloodBuff) then
    if Cast(S.VampiricBlood, Settings.Blood.GCDasOffGCD.VampiricBlood) then return "vampiric_blood defensives 12"; end
  end
  -- Death Strike Healing
  -- Note: If under 50% health (or 70% health, if RP is above VarDeathStrikeDumpAmt).
  if S.DeathStrike:IsReady() and Player:HealthPercentage() <= 50 + (Player:RunicPower() > VarDeathStrikeDumpAmt and 20 or 0) and not Player:HealingAbsorbed() then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 14"; end
  end
end

local function Deathbringer()
  -- variable,name=death_strike_dump_amount,value=50
  -- variable,name=bone_shield_refresh_value,value=9
  -- Note: Above variables set in variable declarations and Event Registrations.
  -- variable,name=heart_strike_rp_drw,value=(25+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRPDRW = 25 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2
  -- potion,if=buff.dancing_rune_weapon.up
  if Settings.Commons.Enabled.Potions and Player:BuffUp(S.DancingRuneWeaponBuff) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion deathbringer 2"; end
    end
  end
  -- deaths_caress,if=!buff.bone_shield.up
  if S.DeathsCaress:IsReady() and (Player:BuffDown(S.BoneShieldBuff)) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress deathbringer 4"; end
  end
  -- death_strike,if=buff.coagulopathy.remains<=gcd|runic_power.deficit<35
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD() or Player:RunicPowerDeficit() < 35) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike deathbringer 6"; end
  end
  -- blood_boil,if=pet.dancing_rune_weapon.active&pet.dancing_rune_weapon.remains>=(14-2*gcd)
  if S.BloodBoil:IsCastable() and (Player:BuffUp(S.DancingRuneWeaponBuff) and Player:BuffRemains(S.DancingRuneWeaponBuff) >= (14 - 2 * Player:GCD())) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 8"; end
  end
  -- blood_boil,if=dot.reapers_mark.ticking&dot.reapers_mark.remains<3
  if S.BloodBoil:IsCastable() and (Target:DebuffUp(S.ReapersMarkDebuff) and Target:DebuffRemains(S.ReapersMarkDebuff) < 3) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 10"; end
  end
  -- use_items,if=buff.bone_shield.stack>=10
  if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and VarBoneShieldStacks >= 10 then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "use_items deathbringer 12"; end
      end
    end
  end
  -- blood_boil,if=!dot.blood_plague.ticking|(charges_fractional>=1&dot.reapers_mark.ticking&buff.coagulopathy.remains>2*gcd)
  if S.BloodBoil:IsCastable() and (S.BloodPlagueDebuff:AuraActiveCount() == 0 or (S.BloodBoil:ChargesFractional() >= 1 and Target:DebuffUp(S.ReapersMarkDebuff) and Player:BuffRemains(S.CoagulopathyBuff) > 2 * Player:GCD())) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 14"; end
  end
  -- death_and_decay,if=(dot.reapers_mark.ticking&!death_and_decay.ticking)|!buff.death_and_decay.up
  if S.DeathAndDecay:IsReady() and ((Target:DebuffUp(S.ReapersMarkDebuff) and not Player:DnDTicking()) or Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay deathbringer 16"; end
  end
  -- marrowrend,if=(buff.exterminate_painful_death.up|buff.exterminate.up)&(runic_power.deficit>30&buff.coagulopathy.remains>2*gcd)
  if S.Marrowrend:IsReady() and ((Player:BuffUp(S.PainfulDeathBuff) or Player:BuffUp(S.ExterminateBuff)) and (Player:RunicPowerDeficit() > 30 and Player:BuffRemains(S.CoagulopathyBuff) > 2 * Player:GCD())) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend deathbringer 18"; end
  end
  -- raise_dead
  if CDsON() and S.RaiseDead:IsCastable() then
    if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead deathbringer 20"; end
  end
  -- abomination_limb,if=dot.reapers_mark.ticking
  if CDsON() and S.AbominationLimb:IsCastable() and (Target:DebuffUp(S.ReapersMarkDebuff)) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb deathbringer 22"; end
  end
  -- reapers_mark,if=!dot.reapers_mark.ticking
  if S.ReapersMark:IsReady() and (Target:DebuffDown(S.ReapersMarkDebuff)) then
    if Cast(S.ReapersMark, nil, nil, not Target:IsInMeleeRange(5)) then return "reapers_mark deathbringer 24"; end
  end
  -- bonestorm,if=buff.bone_shield.stack>5&cooldown.dancing_rune_weapon.remains>=10&dot.reapers_mark.ticking
  if CDsON() and S.Bonestorm:IsReady() and (VarBoneShieldStacks >= 5 and S.DancingRuneWeapon:CooldownRemains() >= 10 and Target:DebuffUp(S.ReapersMarkDebuff)) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm deathbringer 26"; end
  end
  -- consumption,if=dot.reapers_mark.ticking
  if S.Consumption:IsCastable() and (Target:DebuffUp(S.ReapersMarkDebuff)) then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption deathbringer 28"; end
  end
  -- abomination_limb
  if CDsON() and S.AbominationLimb:IsCastable() then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb deathbringer 30"; end
  end
  -- blooddrinker,if=buff.coagulopathy.remains>4&!buff.dancing_rune_weapon.up
  if S.Blooddrinker:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) > 4 and Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker deathbringer 32"; end
  end
  -- dancing_rune_weapon,if=!buff.dancing_rune_weapon.up&buff.coagulopathy.remains>2*gcd
  if CDsON() and S.DancingRuneWeapon:IsCastable() and (Player:BuffDown(S.DancingRuneWeaponBuff) and Player:BuffRemains(S.CoagulopathyBuff) > 2 * Player:GCD()) then
    if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon deathbringer 34"; end
  end
  -- marrowrend,if=!dot.bonestorm.ticking&(buff.bone_shield.stack<variable.bone_shield_refresh_value&runic_power.deficit>20|buff.bone_shield.remains<=3)
  if S.Marrowrend:IsReady() and (not Player:BonestormTicking() and (VarBoneShieldStacks < VarBoneShieldRefreshValue and Player:RunicPowerDeficit() > 20 or Player:BuffRemains(S.BoneShieldBuff) <= 3)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend deathbringer 36"; end
  end
  if CDsON() and S.DancingRuneWeapon:CooldownUp() then
    -- blood_fury,if=cooldown.dancing_rune_weapon.ready
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury deathbringer 38"; end
    end
    -- berserking,if=cooldown.dancing_rune_weapon.ready
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking deathbringer 40"; end
    end
  end
  -- tombstone,if=cooldown.bonestorm.up&buff.bone_shield.stack>10&runic_power.deficit>=30&cooldown.dancing_rune_weapon.remains>=10
  if S.Tombstone:IsReady() and (S.Bonestorm:CooldownUp() and VarBoneShieldStacks > 10 and Player:RunicPowerDeficit() >= 30 and S.DancingRuneWeapon:CooldownRemains() >= 10) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone deathbringer 42"; end
  end
  -- bonestorm,if=buff.bone_shield.stack>5&cooldown.dancing_rune_weapon.remains>=10
  if CDsON() and S.Bonestorm:IsReady() and (VarBoneShieldStacks > 5 and S.DancingRuneWeapon:CooldownRemains() >= 10) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm deathbringer 44"; end
  end
  -- tombstone,if=buff.bone_shield.stack>5&runic_power.deficit>=30&cooldown.dancing_rune_weapon.remains>=10
  if S.Tombstone:IsReady() and (VarBoneShieldStacks > 5 and Player:RunicPowerDeficit() >= 30 and S.DancingRuneWeapon:CooldownRemains() >= 10) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone deathbringer 46"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and Target:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper deathbringer 48"; end
  end
  -- blood_boil,if=charges>=2|(full_recharge_time<=gcd.max)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:Charges() >= 2 or (S.BloodBoil:FullRechargeTime() <= Player:GCD())) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 50"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption deathbringer 52"; end
  end
  -- death_strike,if=runic_power.deficit<=variable.heart_strike_rp_drw|runic_power>=variable.death_strike_dump_amount
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW or Player:RunicPower() >= VarDeathStrikeDumpAmt) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike deathbringer 54"; end
  end
  -- blood_tap,if=rune<=1
  if CDsON() and S.BloodTap:IsCastable() and (Player:Rune() <= 1) then
    if Cast(S.BloodTap, Settings.Blood.OffGCDasOffGCD.BloodTap) then return "blood_tap deathbringer 56"; end
  end
  -- blood_boil,if=charges_fractional>=1.1&buff.hemostasis.stack<5
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.1 and Player:BuffStack(S.HemostasisBuff) < 5) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 58"; end
  end
  -- heart_strike,if=rune.time_to_2<gcd|runic_power.deficit>=variable.heart_strike_rp_drw
  if S.HeartStrike:IsReady() and (Player:RuneTimeToX(2) < Player:GCD() or Player:RunicPowerDeficit() >= VarHeartStrikeRPDRW) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike deathbringer 60"; end
  end
  -- blood_boil
  if S.BloodBoil:IsCastable() then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 62"; end
  end
end

local function Sanlayn()
  -- variable,name=death_strike_dump_amount,value=65
  -- variable,name=bone_shield_refresh_value,value=12
  -- Note: Above variables set in variable declarations and Event Registrations.
  -- variable,name=heart_strike_rp_drw,value=(25+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRPDRW = 25 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2
  -- potion,if=buff.dancing_rune_weapon.up
  if Settings.Commons.Enabled.Potions and Player:BuffUp(S.DancingRuneWeaponBuff) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion sanlayn 2"; end
    end
  end
  -- heart_strike,if=buff.vampiric_blood.up&(buff.essence_of_the_blood_queen.remains<2*gcd)
  if S.HeartStrike:IsReady() and (Player:BuffUp(S.VampiricBloodBuff) and (Player:BuffRemains(S.EssenceoftheBloodQueenBuff) < 2 * Player:GCD())) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike sanlayn 4"; end
  end
  -- heart_strike,if=buff.vampiric_strike.up&(buff.essence_of_the_blood_queen.remains<3)
  if S.HeartStrike:IsReady() and (Player:BuffUp(S.VampiricStrikeBuff) and (Player:BuffRemains(S.EssenceoftheBloodQueenBuff) < 3)) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike sanlayn 6"; end
  end
  -- vampiric_blood,if=!(cooldown.bonestorm.up|cooldown.dancing_rune_weapon.up|cooldown.tombstone.up)
  if S.VampiricBlood:IsCastable() and (not (S.Bonestorm:CooldownUp() or S.DancingRuneWeapon:CooldownUp() or S.Tombstone:CooldownUp())) then
    if Cast(S.VampiricBlood, Settings.Blood.GCDasOffGCD.VampiricBlood) then return "vampiric_blood sanlayn 8"; end
  end
  -- deaths_caress,if=!buff.bone_shield.up
  if S.DeathsCaress:IsReady() and (Player:BuffDown(S.BoneShieldBuff)) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress sanlayn 10"; end
  end
  -- death_strike,if=buff.coagulopathy.remains<=gcd
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD()) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsInMeleeRange(5)) then return "death_strike sanlayn 12"; end
  end
  -- use_items,if=buff.bone_shield.stack>=10
  if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and VarBoneShieldStacks >= 10 then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "use_items sanlayn 14"; end
      end
    end
  end
  -- blood_boil,if=!dot.blood_plague.ticking
  if S.BloodBoil:IsReady() and (Target:DebuffDown(S.BloodPlagueDebuff)) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil sanlayn 16"; end
  end
  -- death_and_decay,if=!death_and_decay.ticking
  if S.DeathAndDecay:IsReady() and (not Player:DnDTicking()) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay sanlayn 18"; end
  end
  -- raise_dead
  if CDsON() and S.RaiseDead:IsCastable() then
    if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead sanlayn 20"; end
  end
  -- dancing_rune_weapon,if=!buff.dancing_rune_weapon.up
  if CDsON() and S.DancingRuneWeapon:IsCastable() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon sanlayn 22"; end
  end
  -- marrowrend,if=!dot.bonestorm.ticking&(buff.bone_shield.stack<variable.bone_shield_refresh_value&runic_power.deficit>20|buff.bone_shield.remains<=3)
  if S.Marrowrend:IsReady() and (not Player:BonestormTicking() and (VarBoneShieldStacks < VarBoneShieldRefreshValue and Player:RunicPowerDeficit() > 20 or Player:BuffRemains(S.BoneShieldBuff) <= 3)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend sanlayn 24"; end
  end
  -- consumption,if=buff.vampiric_blood.remains<=3|buff.infliction_of_sorrow.up|cooldown.vampiric_blood.remains>5
  if S.Consumption:IsCastable() and (Player:BuffRemains(S.VampiricBloodBuff) <= 3 or Player:BuffUp(S.InflictionofSorrowBuff) or S.VampiricBlood:CooldownRemains() > 5) then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption sanlayn 26"; end
  end
  -- death_strike,if=(buff.vampiric_blood.up&buff.coagulopathy.remains<3)
  if S.DeathStrike:IsReady() and (Player:BuffUp(S.VampiricBloodBuff) and Player:BuffRemains(S.CoagulopathyBuff) < 3) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike sanlayn 28"; end
  end
  -- heart_strike,if=buff.vampiric_strike.up
  if S.HeartStrike:IsReady() and (Player:BuffUp(S.VampiricStrikeBuff)) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike sanlayn 30"; end
  end
  -- abomination_limb
  if CDsON() and S.AbominationLimb:IsCastable() then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb sanlayn 32"; end
  end
  if CDsON() and S.DancingRuneWeapon:CooldownUp() then
    -- blood_fury,if=cooldown.dancing_rune_weapon.ready
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury sanlayn 34"; end
    end
    -- berserking,if=cooldown.dancing_rune_weapon.ready
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking sanlayn 36"; end
    end
  end
  -- bonestorm,if=buff.bone_shield.stack>5&cooldown.dancing_rune_weapon.remains>=25
  if CDsON() and S.Bonestorm:IsReady() and (VarBoneShieldStacks > 5 and S.DancingRuneWeapon:CooldownRemains() >= 25) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm sanlayn 38"; end
  end
  -- tombstone,if=buff.bone_shield.stack>5&runic_power.deficit>=30&cooldown.dancing_rune_weapon.remains>=25
  if S.Tombstone:IsReady() and (VarBoneShieldStacks > 5 and Player:RunicPowerDeficit() >= 30 and S.DancingRuneWeapon:CooldownRemains() >= 25) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone sanlayn 40"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and Target:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper sanlayn 42"; end
  end
  -- blood_boil,if=charges>=2|(full_recharge_time<=gcd.max)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:Charges() >= 2 or (S.BloodBoil:FullRechargeTime() <= Player:GCD())) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil sanlayn 44"; end
  end
  -- death_strike,if=runic_power.deficit<=variable.heart_strike_rp_drw|runic_power>=variable.death_strike_dump_amount
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW or Player:RunicPower() >= VarDeathStrikeDumpAmt) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike sanlayn 46"; end
  end
  -- blood_boil
  if S.BloodBoil:IsCastable() then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil sanlayn 48"; end
  end
end

--- ===== APL Main =====
local function APL()
  -- Get Enemies Count
  EnemiesMelee = Player:GetEnemiesInMeleeRange(5)
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
  else
    EnemiesMeleeCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- HeartStrike is limited to 5 targets maximum
    HeartStrikeCount = mathmin(EnemiesMeleeCount, Player:BuffUp(S.DeathAndDecayBuff) and 5 or 2)

    -- Check Units without Blood Plague
    UnitsWithoutBloodPlague = UnitsWithoutBP(EnemiesMelee)

    -- Are we actively tanking?
    IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

    -- Bone Shield Stacks
    VarBoneShieldStacks = Player:BuffStack(S.BoneShieldBuff)
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Defensives
    if IsTanking then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.MindFreeze, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Display Pool icon if PoolDuringBlooddrinker is true
    if Settings.Blood.PoolDuringBlooddrinker and Player:IsChanneling(S.Blooddrinker) and Player:BuffUp(S.BoneShieldBuff) and UnitsWithoutBloodPlague == 0 and Player:CastRemains() > 0.2 then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool During Blooddrinker"; end
    end
    -- auto_attack
    -- run_action_list,name=deathbringer,if=hero_tree.deathbringer
    if Player:HeroTreeID() == 33 or Player:Level() <= 70 then
      local ShouldReturn = Deathbringer(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Deathbringer()"; end
    end
    -- run_action_list,name=sanlayn,if=hero_tree.sanlayn
    if Player:HeroTreeID() == 31 then
      local ShouldReturn = Sanlayn(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Sanlayn()"; end
    end
  end
end

local function Init()
  S.BloodPlagueDebuff:RegisterAuraTracking()

  HR.Print("Blood Death Knight rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(250, APL, Init)
