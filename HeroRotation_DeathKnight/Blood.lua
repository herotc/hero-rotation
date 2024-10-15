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
local VarDeathStrikeDumpAmt = S.ReapersMark:IsAvailable() and 35 or 50
local VarDeathStrikePreEssenceDumpAmt = 20
local VarBoneShieldRefreshValue = S.ReapersMark:IsAvailable() and 6 or 11
local VarHeartStrikeRPDRW = 21 + num(S.Heartbreaker:IsAvailable()) * 2
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
local VarTrinket1Ex, VarTrinket2Ex
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

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded
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
  VarDeathStrikeDumpAmt = S.ReapersMark:IsAvailable() and 35 or 50
  VarDeathStrikePreEssenceDumpAmt = 20
  VarBoneShieldRefreshValue = S.ReapersMark:IsAvailable() and 6 or 11
  VarHeartStrikeRPDRW = 21 + num(S.Heartbreaker:IsAvailable()) * 2
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

local function DRWBPTicking()
  -- DRW will apply BP if we've casted Blood Boil or Death's Caress since it was summoned.
  return Player:BuffUp(S.DancingRuneWeaponBuff) and (S.BloodBoil:TimeSinceLastCast() < S.DancingRuneWeapon:TimeSinceLastCast() or S.DeathsCaress:TimeSinceLastCast() < S.DancingRuneWeapon:TimeSinceLastCast())
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
  -- variable,name=death_strike_dump_amount,value=35
  -- variable,name=bone_shield_refresh_value,value=6
  -- Note: Above variables set in variable declarations and Event Registrations.
  -- variable,name=heart_strike_rp_drw,value=(21+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRPDRW = 21 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2
  -- potion,if=buff.dancing_rune_weapon.up
  if Settings.Commons.Enabled.Potions and Player:BuffUp(S.DancingRuneWeaponBuff) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion deathbringer 2"; end
    end
  end
  -- blood_tap,if=rune<=1
  if CDsON() and S.BloodTap:IsCastable() and (Player:Rune() <= 1) then
    if Cast(S.BloodTap, Settings.Blood.OffGCDasOffGCD.BloodTap) then return "blood_tap deathbringer 4"; end
  end
  -- raise_dead
  if CDsON() and S.RaiseDead:IsCastable() then
    if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead deathbringer 6"; end
  end
  if CDsON() and S.DancingRuneWeapon:CooldownUp() then
    -- blood_fury,if=cooldown.dancing_rune_weapon.ready
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury deathbringer 8"; end
    end
    -- berserking,if=cooldown.dancing_rune_weapon.ready
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking deathbringer 10"; end
    end
  end
  -- deaths_caress,if=!buff.bone_shield.up
  if S.DeathsCaress:IsReady() and (Player:BuffDown(S.BoneShieldBuff)) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress deathbringer 12"; end
  end
  -- death_strike,if=buff.coagulopathy.remains<=gcd|runic_power.deficit<35
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD() or Player:RunicPowerDeficit() < 35) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike deathbringer 14"; end
  end
  -- blood_boil,if=dot.reapers_mark.ticking&(dot.reapers_mark.remains<2*gcd|charges_fractional>=1.5)
  if S.BloodBoil:IsCastable() and (Target:DebuffUp(S.ReapersMarkDebuff) and (Target:DebuffRemains(S.ReapersMarkDebuff) < 2 * Player:GCD() or S.BloodBoil:ChargesFractional() >= 1.5)) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 16"; end
  end
  -- consumption,if=dot.reapers_mark.ticking&dot.blood_plague.ticking
  if S.Consumption:IsCastable() and (Target:DebuffUp(S.ReapersMarkDebuff) and Target:DebuffUp(S.BloodPlagueDebuff)) then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption deathbringer 18"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and Target:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper deathbringer 20"; end
  end
  -- blood_boil,if=(dot.reapers_mark.ticking&(pet.dancing_rune_weapon.active&!drw.bp_ticking))|!dot.blood_plague.ticking|(charges_fractional>=1&dot.reapers_mark.ticking&buff.coagulopathy.remains>2*gcd)
  if S.BloodBoil:IsCastable() and ((Target:DebuffUp(S.ReapersMarkDebuff) and (Player:BuffUp(S.DancingRuneWeaponBuff) and not DRWBPTicking())) or Target:DebuffDown(S.BloodPlagueDebuff) or (S.BloodBoil:ChargesFractional() >= 1 and Target:DebuffUp(S.ReapersMarkDebuff) and Player:BuffRemains(S.CoagulopathyBuff) > 2 * Player:GCD())) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 22"; end
  end
  -- death_and_decay,if=((dot.reapers_mark.ticking)&!death_and_decay.ticking)|!buff.death_and_decay.up
  if S.DeathAndDecay:IsReady() and ((Target:DebuffUp(S.ReapersMarkDebuff) and not Player:DnDTicking()) or Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay deathbringer 24"; end
  end
  -- marrowrend,if=(buff.exterminate_painful_death.up|buff.exterminate.up)&(runic_power.deficit>20&buff.coagulopathy.remains>2*gcd)
  if S.Marrowrend:IsReady() and ((Player:BuffUp(S.PainfulDeathBuff) or Player:BuffUp(S.ExterminateBuff)) and (Player:RunicPowerDeficit() > 20 and Player:BuffRemains(S.CoagulopathyBuff) > 2 * Player:GCD())) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend deathbringer 26"; end
  end
  -- abomination_limb,if=dot.reapers_mark.ticking
  if CDsON() and S.AbominationLimb:IsCastable() and (Target:DebuffUp(S.ReapersMarkDebuff)) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb deathbringer 28"; end
  end
  -- reapers_mark,if=!dot.reapers_mark.ticking&dot.blood_plague.ticking
  if S.ReapersMark:IsReady() and (Target:DebuffDown(S.ReapersMarkDebuff) and Target:DebuffDown(S.BloodPlagueDebuff)) then
    if Cast(S.ReapersMark, nil, nil, not Target:IsInMeleeRange(5)) then return "reapers_mark deathbringer 30"; end
  end
  -- bonestorm,if=buff.death_and_decay.up&buff.bone_shield.stack>5&cooldown.dancing_rune_weapon.remains>=10&(dot.reapers_mark.ticking)
  if CDsON() and S.Bonestorm:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and VarBoneShieldStacks > 5 and S.DancingRuneWeapon:CooldownRemains() >= 10 and Target:DebuffUp(S.ReapersMarkDebuff)) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm deathbringer 32"; end
  end
  -- abomination_limb
  if CDsON() and S.AbominationLimb:IsCastable() then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb deathbringer 34"; end
  end
  -- blooddrinker,if=buff.coagulopathy.remains>3*gcd&!buff.dancing_rune_weapon.up
  if S.Blooddrinker:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) > 3 * Player:GCD() and Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker deathbringer 36"; end
  end
  -- dancing_rune_weapon,if=buff.coagulopathy.remains>2*gcd
  if CDsON() and S.DancingRuneWeapon:IsCastable() and (Player:BuffRemains(S.CoagulopathyBuff) > 2 * Player:GCD()) then
    if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon deathbringer 38"; end
  end
  -- bonestorm,if=buff.death_and_decay.up&buff.bone_shield.stack>5&cooldown.dancing_rune_weapon.remains>=10
  if CDsON() and S.Bonestorm:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and VarBoneShieldStacks > 5 and S.DancingRuneWeapon:CooldownRemains() >= 10) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm deathbringer 40"; end
  end
  -- tombstone,if=buff.death_and_decay.up&buff.bone_shield.stack>5&runic_power.deficit>=30&cooldown.dancing_rune_weapon.remains>=10
  if S.Tombstone:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and VarBoneShieldStacks > 5 and Player:RunicPowerDeficit() >= 30 and S.DancingRuneWeapon:CooldownRemains() >= 10) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone deathbringer 42"; end
  end
  -- marrowrend,if=!dot.bonestorm.ticking&(buff.bone_shield.stack<variable.bone_shield_refresh_value&runic_power.deficit>20|buff.bone_shield.remains<=3)
  if S.Marrowrend:IsReady() and (not Player:BonestormTicking() and (VarBoneShieldStacks < VarBoneShieldRefreshValue and Player:RunicPowerDeficit() > 20 or Player:BuffRemains(S.BoneShieldBuff) <= 3)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend deathbringer 44"; end
  end
  -- blood_boil,if=charges_fractional>=1.5|(full_recharge_time<=gcd.max)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.5 or (S.BloodBoil:FullRechargeTime() <= Player:GCD())) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 46"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption deathbringer 48"; end
  end
  -- death_strike,if=runic_power.deficit<=variable.heart_strike_rp_drw|runic_power>=variable.death_strike_dump_amount
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW or Player:RunicPower() >= VarDeathStrikeDumpAmt) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike deathbringer 50"; end
  end
  -- blood_boil,if=charges_fractional>=1.5&buff.hemostasis.stack<5&cooldown.reapers_mark.remains>5
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.5 and Player:BuffStack(S.HemostasisBuff) < 5 and S.ReapersMark:CooldownRemains() > 5) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 52"; end
  end
  -- heart_strike,if=rune>=1|rune.time_to_2<gcd|runic_power.deficit>=variable.heart_strike_rp_drw
  if S.HeartStrike:IsReady() and (Player:Rune() >= 1 or Player:RuneTimeToX(2) < Player:GCD() or Player:RunicPowerDeficit() >= VarHeartStrikeRPDRW) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike deathbringer 54"; end
  end
end

local function Sanlayn()
  -- variable,name=death_strike_dump_amount,value=50
  -- variable,name=death_strike_pre_essence_dump_amount,value=20
  -- variable,name=bone_shield_refresh_value,value=11
  -- Note: Above variables set in variable declarations and Event Registrations.
  -- variable,name=heart_strike_rp_drw,value=(21+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRPDRW = 21 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2
  -- death_strike,if=buff.coagulopathy.remains<=gcd
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD()) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsInMeleeRange(5)) then return "death_strike sanlayn 2"; end
  end
  -- raise_dead
  if CDsON() and S.RaiseDead:IsCastable() then
    if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead sanlayn 4"; end
  end
  -- potion,if=buff.dancing_rune_weapon.up
  if Settings.Commons.Enabled.Potions and Player:BuffUp(S.DancingRuneWeaponBuff) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion sanlayn 6"; end
    end
  end
  if CDsON() and S.DancingRuneWeapon:CooldownUp() then
    -- blood_fury,if=cooldown.dancing_rune_weapon.ready
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury sanlayn 8"; end
    end
    -- berserking,if=cooldown.dancing_rune_weapon.ready
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking sanlayn 10"; end
    end
  end
  -- blood_tap,if=rune<3
  if CDsON() and S.BloodTap:IsCastable() and (Player:Rune() < 3) then
    if Cast(S.BloodTap, Settings.Blood.OffGCDasOffGCD.BloodTap) then return "blood_tap sanlayn 12"; end
  end
  -- blood_boil,if=!dot.blood_plague.ticking|(dot.blood_plague.remains<10&buff.vampiric_blood.up)
  if S.BloodBoil:IsReady() and (Target:DebuffDown(S.BloodPlagueDebuff) or (Target:DebuffRemains(S.BloodPlagueDebuff) < 10 and Player:BuffUp(S.VampiricBloodBuff))) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil sanlayn 14"; end
  end
  -- abomination_limb,if=buff.coagulopathy.remains>=2*gcd&(!buff.essence_of_the_blood_queen.up|buff.essence_of_the_blood_queen.remains>=3*gcd)&(!buff.vampiric_blood.up|buff.vampiric_blood.remains>=6*gcd)
  if CDsON() and S.AbominationLimb:IsCastable() and (Player:BuffRemains(S.CoagulopathyBuff) >= 2 * Player:GCD() and (Player:BuffDown(S.EssenceoftheBloodQueenBuff) or Player:BuffRemains(S.EssenceoftheBloodQueenBuff) >= 3 * Player:GCD()) and (Player:BuffDown(S.VampiricBloodBuff) or Player:BuffRemains(S.VampiricBloodBuff) >= 6 * Player:GCD())) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb sanlayn 16"; end
  end
  -- blood_boil,if=cooldown.vampiric_blood.remains<3*gcd&buff.coagulopathy.remains>=gcd
  if S.BloodBoil:IsReady() and (S.VampiricBlood:CooldownRemains() < 3 * Player:GCD() and Player:BuffRemains(S.CoagulopathyBuff) >= Player:GCD()) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil sanlayn 18"; end
  end
  -- heart_strike,if=buff.vampiric_blood.up&(buff.vampiric_blood.remains<2*gcd)
  if S.HeartStrike:IsReady() and (Player:BuffUp(S.VampiricBloodBuff) and (Player:BuffRemains(S.VampiricBloodBuff) < 2 * Player:GCD())) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike sanlayn 20"; end
  end
  -- bonestorm,if=(!buff.vampiric_blood.up&buff.death_and_decay.up)&buff.bone_shield.stack>5&cooldown.dancing_rune_weapon.remains>=10&buff.coagulopathy.remains>3*gcd
  if CDsON() and S.Bonestorm:IsReady() and ((Player:BuffDown(S.VampiricBloodBuff) and Player:BuffUp(S.DeathAndDecayBuff)) and VarBoneShieldStacks > 5 and S.DancingRuneWeapon:CooldownRemains() >= 10 and Player:BuffRemains(S.CoagulopathyBuff) > 3 * Player:GCD()) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm sanlayn 22"; end
  end
  -- tombstone,if=(!buff.vampiric_blood.up&buff.death_and_decay.up)&buff.bone_shield.stack>5&runic_power.deficit>=30&cooldown.dancing_rune_weapon.remains>=10&buff.coagulopathy.remains>2*gcd
  if S.Tombstone:IsReady() and ((Player:BuffDown(S.VampiricBloodBuff) and Player:BuffUp(S.DeathAndDecayBuff)) and VarBoneShieldStacks > 5 and Player:RunicPowerDeficit() >= 30 and S.DancingRuneWeapon:CooldownRemains() >= 10 and Player:BuffRemains(S.CoagulopathyBuff) > 2 * Player:GCD()) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone sanlayn 24"; end
  end
  -- dancing_rune_weapon,if=buff.coagulopathy.remains>=2*gcd&(!buff.essence_of_the_blood_queen.up|buff.essence_of_the_blood_queen.remains>=3*gcd)&(!buff.vampiric_blood.up|buff.vampiric_blood.remains>=6*gcd)
  if CDsON() and S.DancingRuneWeapon:IsCastable() and (Player:BuffRemains(S.CoagulopathyBuff) >= 2 * Player:GCD() and (Player:BuffDown(S.EssenceoftheBloodQueenBuff) or Player:BuffRemains(S.EssenceoftheBloodQueenBuff) >= 3 * Player:GCD()) and (Player:BuffDown(S.VampiricBloodBuff) or Player:BuffRemains(S.VampiricBloodBuff) >= 6 * Player:GCD())) then
    if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon sanlayn 26"; end
  end
  -- death_strike,if=!buff.vampiric_strike.up&cooldown.vampiric_blood.remains<=30&runic_power>variable.death_strike_pre_essence_dump_amount&buff.essence_of_the_blood_queen.stack>=3
  if S.DeathStrike:IsReady() and (Player:BuffDown(S.VampiricStrikeBuff) and S.VampiricBlood:CooldownRemains() <= 30 and Player:RunicPower() > VarDeathStrikePreEssenceDumpAmt and Player:BuffStack(S.EssenceoftheBloodQueenBuff) >= 3) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike sanlayn 28"; end
  end
  -- heart_strike,if=(buff.vampiric_blood.up)&(buff.coagulopathy.remains>2*gcd)
  if S.HeartStrike:IsReady() and (Player:BuffUp(S.VampiricBloodBuff) and (Player:BuffRemains(S.CoagulopathyBuff) > 2 * Player:GCD())) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike sanlayn 30"; end
  end
  -- consumption,if=buff.vampiric_blood.remains<=3|buff.infliction_of_sorrow.up|cooldown.vampiric_blood.remains>5
  if S.Consumption:IsCastable() and (Player:BuffRemains(S.VampiricBloodBuff) <= 3 or Player:BuffUp(S.InflictionofSorrowBuff) or S.VampiricBlood:CooldownRemains() > 5) then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption sanlayn 32"; end
  end
  -- death_strike,if=buff.vampiric_blood.up&(buff.coagulopathy.remains<2*gcd|(runic_power.deficit<=variable.heart_strike_rp_drw&buff.incite_terror.stack>=3))
  if S.DeathStrike:IsReady() and (Player:BuffUp(S.VampiricBloodBuff) and (Player:BuffRemains(S.CoagulopathyBuff) < 2 * Player:GCD() or (Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW and Target:DebuffStack(S.InciteTerrorDebuff) >= 3))) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike sanlayn 34"; end
  end
  -- heart_strike,if=buff.vampiric_strike.up|buff.infliction_of_sorrow.up&((talent.consumption.enabled&buff.consumption.up)|!talent.consumption.enabled)&dot.blood_plague.ticking&dot.blood_plague.remains>20
  if S.HeartStrike:IsReady() and (Player:BuffUp(S.VampiricStrikeBuff) or Player:BuffUp(S.InflictionofSorrowBuff) and ((S.Consumption:IsAvailable() and Player:BuffUp(S.ConsumptionBuff)) or not S.Consumption:IsAvailable()) and Target:DebuffUp(S.BloodPlagueDebuff) and Target:DebuffRemains(S.BloodPlagueDebuff) > 20) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike sanlayn 36"; end
  end
  -- vampiric_blood,if=buff.coagulopathy.up
  if S.VampiricBlood:IsCastable() and (Player:BuffUp(S.CoagulopathyBuff)) then
    if Cast(S.VampiricBlood, Settings.Blood.GCDasOffGCD.VampiricBlood) then return "vampiric_blood sanlayn 38"; end
  end
  -- deaths_caress,if=!buff.bone_shield.up
  if S.DeathsCaress:IsReady() and (Player:BuffDown(S.BoneShieldBuff)) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress sanlayn 40"; end
  end
  -- death_and_decay,if=!buff.death_and_decay.up|(buff.crimson_scourge.up&(!buff.vampiric_blood.up|buff.vampiric_blood.remains>3*gcd))
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) or (Player:BuffUp(S.CrimsonScourgeBuff) and (Player:BuffDown(S.VampiricBloodBuff) or Player:BuffRemains(S.VampiricBloodBuff) > 3 * Player:GCD()))) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay sanlayn 42"; end
  end
  -- marrowrend,if=!dot.bonestorm.ticking&(buff.bone_shield.stack<variable.bone_shield_refresh_value&runic_power.deficit>20|buff.bone_shield.remains<=3)
  if S.Marrowrend:IsReady() and (not Player:BonestormTicking() and (VarBoneShieldStacks < VarBoneShieldRefreshValue and Player:RunicPowerDeficit() > 20 or Player:BuffRemains(S.BoneShieldBuff) <= 3)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend sanlayn 44"; end
  end
  -- death_strike,if=runic_power.deficit<=variable.heart_strike_rp_drw|runic_power>=variable.death_strike_dump_amount
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW or Player:RunicPower() >= VarDeathStrikeDumpAmt) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike sanlayn 46"; end
  end
  -- heart_strike,if=rune>1
  if S.HeartStrike:IsReady() and (Player:Rune() > 1) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike sanlayn 48"; end
  end
  -- bonestorm,if=buff.death_and_decay.up&buff.bone_shield.stack>5&cooldown.dancing_rune_weapon.remains>=10
  if CDsON() and S.Bonestorm:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and VarBoneShieldStacks > 5 and S.DancingRuneWeapon:CooldownRemains() >= 10) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm sanlayn 50"; end
  end
  -- tombstone,if=buff.death_and_decay.up&buff.bone_shield.stack>5&runic_power.deficit>=30&cooldown.dancing_rune_weapon.remains>=10
  if S.Tombstone:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and VarBoneShieldStacks > 5 and Player:RunicPowerDeficit() >= 30 and S.DancingRuneWeapon:CooldownRemains() >= 10) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone sanlayn 52"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and Target:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper sanlayn 54"; end
  end
  -- blood_boil,if=charges>=2|(full_recharge_time<=gcd.max)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:Charges() >= 2 or (S.BloodBoil:FullRechargeTime() <= Player:GCD())) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil sanlayn 56"; end
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
    -- use_items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "use_items ("..ItemToUse:Name()..") main 2"; end
        end
      end
    end
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
