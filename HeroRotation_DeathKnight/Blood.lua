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
  I.TomeofLightsDevotion:ID(),
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
local VarDeathStrikeDumpDRWAmt = 80
local VarDeathStrikeDumpAmt = 35
local VarDeathStrikePreEssenceDumpAmt = 20
local VarDeathStrikeSangLowHP = 40
local VarDeathStrikePreEssenceDumpAmtLowHP = 70
local VarBoneShieldRefreshValue = 7
local VarHeartStrikeRPDRW = 21 + num(S.Heartbreaker:IsAvailable()) * 2
local VarBoneShieldStacks
local IsTanking
local EnemiesMelee
local EnemiesMeleeCount
local HeartStrikeCount
local UnitsWithoutBloodPlague
local HSAction
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
  VarDeathStrikeDumpDRWAmt = 80
  VarDeathStrikeDumpAmt = 35
  VarDeathStrikePreEssenceDumpAmt = 20
  VarDeathStrikeSangLowHP = 40
  VarDeathStrikePreEssenceDumpAmtLowHP = 70
  VarBoneShieldRefreshValue = 7
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
  -- deaths_caress
  if S.DeathsCaress:IsReady() then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress precombat 4"; end
  end
  -- Manually added: marrowrend
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

local function Sequence()
  -- sequence,name=drw_bp:blood_boil
  -- Note: DRW can apply BP, so we want to force the application.
  if S.BloodBoil:IsCastable() and (Player:BuffUp(S.DancingRuneWeaponBuff) and S.BloodBoil:TimeSinceLastCast() > S.DancingRuneWeapon:TimeSinceLastCast()) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil sequence 2"; end
  end
end

local function Deathbringer()
  -- rune_tap,if=rune>2
  -- Note: Handled in Defensives().
  -- dancing_rune_weapon
  if CDsON() and S.DancingRuneWeapon:IsCastable() then
    if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon deathbringer 2"; end
  end
  -- death_strike,if=buff.coagulopathy.remains<=gcd
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD()) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike deathbringer 4"; end
  end
  -- marrowrend,if=!buff.bone_shield.up|buff.bone_shield.remains<1.5|buff.bone_shield.stack<=1
  -- marrowrend,if=(buff.exterminate.up)&(cooldown.reapers_mark.up|cooldown.reapers_mark.remains<3)
  if S.Marrowrend:IsReady() and (
    (Player:BuffDown(S.BoneShieldBuff) or Player:BuffRemains(S.BoneShieldBuff) < 1.5 or VarBoneShieldStacks <= 1) or
    ((Player:BuffUp(S.ExterminateBuff)) and (S.ReapersMark:CooldownUp() or S.ReapersMark:CooldownRemains() < 3))
  ) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend deathbringer 6"; end
  end
  -- deaths_caress,if=!buff.bone_shield.up|buff.bone_shield.remains<1.5|buff.bone_shield.stack<=1
  if S.DeathsCaress:IsReady() and (Player:BuffDown(S.BoneShieldBuff) or Player:BuffRemains(S.BoneShieldBuff) < 1.5 or VarBoneShieldStacks <= 1) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress deathbringer 8"; end
  end
  -- blood_boil,if=dot.blood_plague.remains<3
  if S.BloodBoil:IsCastable() and (Target:DebuffRemains(S.BloodPlagueDebuff) < 3) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 10"; end
  end
  -- bonestorm,if=buff.bone_shield.stack>=5&(!talent.shattering_bone.enabled|death_and_decay.ticking)&!buff.dancing_rune_weapon.remains
  if CDsON() and S.Bonestorm:IsReady() and (VarBoneShieldStacks > 5 and (not S.ShatteringBone:IsAvailable() or Player:DnDTicking()) and Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm deathbringer 12"; end
  end
  -- soul_reaper,if=active_enemies<=2&buff.reaper_of_souls.up&target.time_to_die>(dot.soul_reaper.remains+5)
  -- soul_reaper,if=active_enemies<=2&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (
    (EnemiesMeleeCount <= 2 and Player:BuffUp(S.ReaperofSoulsBuff) and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) or
    (EnemiesMeleeCount <= 2 and Target:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5))
  ) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper deathbringer 14"; end
  end
  -- death_and_decay,if=((dot.reapers_mark.ticking)&!death_and_decay.ticking)|!buff.death_and_decay.up
  if S.DeathAndDecay:IsReady() and ((Target:DebuffUp(S.ReapersMarkDebuff) and not Player:DnDTicking()) or Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay deathbringer 16"; end
  end
  -- marrowrend,if=buff.exterminate.up
  if S.Marrowrend:IsReady() and (Player:BuffUp(S.ExterminateBuff)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend deathbringer 18"; end
  end
  -- bonestorm,if=buff.bone_shield.stack>=5&(!talent.shattering_bone.enabled|death_and_decay.ticking)&buff.dancing_rune_weapon.remains
  if CDsON() and S.Bonestorm:IsReady() and (VarBoneShieldStacks >= 5 and (not S.ShatteringBone:IsAvailable() or Player:DnDTicking()) and Player:BuffUp(S.DancingRuneWeaponBuff)) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm deathbringer 20"; end
  end
  -- death_strike,if=(runic_power.deficit<35|(runic_power.deficit<41&buff.dancing_rune_weapon.up))
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD() or Player:RunicPowerDeficit() < 35) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike deathbringer 14"; end
  end
  -- reapers_mark
  if S.ReapersMark:IsReady() then
    if Cast(S.ReapersMark, nil, nil, not Target:IsInMeleeRange(5)) then return "reapers_mark deathbringer 16"; end
  end
  -- marrowrend,if=buff.bone_shield.stack<6&!dot.bonestorm.ticking
  if S.Marrowrend:IsReady() and (VarBoneShieldStacks < 6 and not Player:BonestormTicking()) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend deathbringer 18"; end
  end
  -- tombstone,if=buff.bone_shield.stack>=8&(!talent.shattering_bone.enabled|death_and_decay.ticking)&cooldown.dancing_rune_weapon.remains>=25
  if S.Tombstone:IsReady() and (VarBoneShieldStacks >= 8 and (not S.ShatteringBone:IsAvailable() or Player:DnDTicking()) and S.DancingRuneWeapon:CooldownRemains() >= 25) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone deathbringer 20"; end
  end
  -- abomination_limb,if=!buff.dancing_rune_weapon.up
  if CDsON() and S.AbominationLimb:IsCastable() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb deathbringer 22"; end
  end
  -- call_action_list,name=sequence,if=buff.dancing_rune_weapon.up&cooldown.blood_boil.charges>=1
  if Player:BuffUp(S.DancingRuneWeaponBuff) and S.BloodBoil:Charges() >= 1 then
    local ShouldReturn = Sequence(); if ShouldReturn then return ShouldReturn; end
  end
  -- any_dnd,if=!buff.death_and_decay.remains
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay deathbringer 24"; end
  end
  -- blooddrinker,if=!buff.dancing_rune_weapon.up&active_enemies<=2&buff.coagulopathy.remains>3
  if S.Blooddrinker:IsReady() and (Player:BuffDown(S.DancingRuneWeaponBuff) and EnemiesMeleeCount <= 2 and Player:BuffRemains(S.CoagulopathyBuff) > 3) then
    if Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker deathbringer 26"; end
  end
  -- death_strike
  if S.DeathStrike:IsReady() then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike deathbringer 28"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption deathbringer 30"; end
  end
  -- blood_boil,if=charges_fractional>=1.5
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.5) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 32"; end
  end
  -- heart_strike,if=rune>=1|rune.time_to_2<gcd
  if HSAction:IsReady() and (Player:Rune() >= 1 or Player:RuneTimeToX(2) < Player:GCD()) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike deathbringer 34"; end
  end
  -- blood_boil
  if S.BloodBoil:IsCastable() then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 36"; end
  end
  -- heart_strike
  if HSAction:IsReady() then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike deathbringer 38"; end
  end
  -- soul_reaper,if=buff.reaper_of_souls.up
  if S.SoulReaper:IsReady() and (Player:BuffUp(S.ReaperofSoulsBuff)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper deathbringer 40"; end
  end
  -- arcane_torrent,if=runic_power.deficit>20
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 20) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent deathbringer 42"; end
  end
  -- deaths_caress,if=buff.bone_shield.stack<11
  if S.DeathsCaress:IsReady() and (VarBoneShieldStacks < 11) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress deathbringer 44"; end
  end
end

local function Sanlayn()
  -- variable,name=death_strike_dump_drw_amount,value=80
  -- variable,name=death_strike_dump_amount,value=35
  -- variable,name=death_strike_pre_essence_dump_amount,value=20
  -- variable,name=death_strike_sang_low_hp,value=40
  -- variable,name=death_strike_pre_essence_dump_amount_low_hp,value=70
  -- variable,name=bone_shield_refresh_value,value=7
  -- Note: Above variables set in variable declarations and Event Registrations.
  -- variable,name=heart_strike_rp_drw,value=(21+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRPDRW = 21 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2
  -- death_strike,if=buff.coagulopathy.remains<=gcd
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD()) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsInMeleeRange(5)) then return "death_strike sanlayn 2"; end
  end
  -- deaths_caress,if=!buff.bone_shield.up
  if S.DeathsCaress:IsReady() and (Player:BuffDown(S.BoneShieldBuff)) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress sanlayn 4"; end
  end
  -- blood_boil,if=!dot.blood_plague.ticking|(dot.blood_plague.remains<10&buff.dancing_rune_weapon.up)
  if S.BloodBoil:IsReady() and (Target:DebuffDown(S.BloodPlagueDebuff) or (Target:DebuffRemains(S.BloodPlagueDebuff) < 10 and Player:BuffUp(S.DancingRuneWeaponBuff))) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil sanlayn 6"; end
  end
  -- potion,if=buff.dancing_rune_weapon.up
  if Settings.Commons.Enabled.Potions and Player:BuffUp(S.DancingRuneWeaponBuff) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion sanlayn 8"; end
    end
  end
  -- consumption,if=pet.dancing_rune_weapon.active&pet.dancing_rune_weapon.remains<=3
  if S.Consumption:IsCastable() and (Player:BuffUp(S.DancingRuneWeaponBuff) and Player:BuffRemains(S.DancingRuneWeaponBuff) <= 3) then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption sanlayn 10"; end
  end
  -- bonestorm,if=(buff.death_and_decay.up)&buff.bone_shield.stack>5&cooldown.dancing_rune_weapon.remains
  if CDsON() and S.Bonestorm:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and VarBoneShieldStacks > 5 and S.DancingRuneWeapon:CooldownDown()) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm sanlayn 12"; end
  end
  -- death_strike,if=runic_power>=108
  if S.DeathStrike:IsReady() and (Player:RunicPower() >= 108) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike sanlayn 14"; end
  end
  -- heart_strike,if=buff.dancing_rune_weapon.up&rune>1
  if HSAction:IsReady() and (Player:BuffUp(S.DancingRuneWeaponBuff) and Player:Rune() > 1) then
    if Cast(HSAction, nil, nil, not Target:IsSpellInRange(HSAction)) then return "heart_strike sanlayn 16"; end
  end
  -- death_and_decay,if=!buff.death_and_decay.up
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay sanlayn 18"; end
  end
  -- heart_strike,if=buff.infliction_of_sorrow.up&buff.death_and_decay.up
  if HSAction:IsReady() and (Player:BuffUp(S.InflictionofSorrowBuff) and Player:BuffUp(S.DeathAndDecayBuff)) then
    if Cast(HSAction, nil, nil, not Target:IsSpellInRange(HSAction)) then return "heart_strike sanlayn 20"; end
  end
  -- raise_dead
  if CDsON() and S.RaiseDead:IsCastable() then
    if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead sanlayn 22"; end
  end
  -- abomination_limb
  if CDsON() and S.AbominationLimb:IsCastable() then
    if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb sanlayn 24"; end
  end
  -- tombstone,if=(!buff.dancing_rune_weapon.up&buff.death_and_decay.up)&buff.bone_shield.stack>5&runic_power.deficit>=30&cooldown.dancing_rune_weapon.remains>=25&buff.coagulopathy.remains>2*gcd
  if S.Tombstone:IsReady() and ((Player:BuffDown(S.DancingRuneWeaponBuff) and Player:BuffUp(S.DeathAndDecayBuff)) and VarBoneShieldStacks > 5 and Player:RunicPowerDeficit() >= 30 and S.DancingRuneWeapon:CooldownRemains() >= 25 and Player:BuffRemains(S.CoagulopathyBuff) > 2 * Player:GCD()) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone sanlayn 26"; end
  end
  -- dancing_rune_weapon,if=buff.coagulopathy.remains>=2*gcd&(!buff.essence_of_the_blood_queen.up|buff.essence_of_the_blood_queen.remains>=3*gcd)&(!buff.dancing_rune_weapon.up|buff.dancing_rune_weapon.remains>=6*gcd)
  if CDsON() and S.DancingRuneWeapon:IsCastable() and (Player:BuffRemains(S.CoagulopathyBuff) >= 2 * Player:GCD() and (Player:BuffDown(S.EssenceoftheBloodQueenBuff) or Player:BuffRemains(S.EssenceoftheBloodQueenBuff) >= 3 * Player:GCD()) and (Player:BuffDown(S.DancingRuneWeaponBuff) or Player:BuffRemains(S.DancingRuneWeaponBuff) >= 6 * Player:GCD())) then
    if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon sanlayn 28"; end
  end
  -- death_strike,if=!buff.vampiric_strike.up&cooldown.dancing_rune_weapon.remains<=10&(target.health.pct<variable.death_strike_sang_low_hp&runic_power>variable.death_strike_pre_essence_dump_amount_low_hp)&buff.essence_of_the_blood_queen.stack>=3
  -- death_strike,if=!buff.vampiric_strike.up&cooldown.dancing_rune_weapon.remains<=10&(target.health.pct>variable.death_strike_sang_low_hp&runic_power>variable.death_strike_pre_essence_dump_amount)&buff.essence_of_the_blood_queen.stack>=3
  if S.DeathStrike:IsReady() and (not S.VampiricStrikeAction:IsReady() and S.DancingRuneWeapon:CooldownRemains() <= 10 and Player:BuffStack(S.EssenceoftheBloodQueenBuff) >= 3) and (
    (Target:HealthPercentage() < VarDeathStrikeSangLowHP and Player:RunicPower() > VarDeathStrikePreEssenceDumpAmtLowHP) or
    (Target:HealthPercentage() > VarDeathStrikeSangLowHP and Player:RunicPower() > VarDeathStrikePreEssenceDumpAmt)
  ) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike sanlayn 30"; end
  end
  -- marrowrend,if=!dot.bonestorm.ticking&(buff.bone_shield.stack<variable.bone_shield_refresh_value&runic_power.deficit>20|buff.bone_shield.remains<=3)
  if S.Marrowrend:IsReady() and (not Player:BonestormTicking() and (VarBoneShieldStacks < VarBoneShieldRefreshValue and Player:RunicPowerDeficit() > 20 or Player:BuffRemains(S.BoneShieldBuff) <= 3)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend sanlayn 32"; end
  end
  -- marrowrend,if=!dot.bonestorm.ticking&(buff.bone_shield.stack<variable.bone_shield_refresh_value&runic_power.deficit>20&!cooldown.dancing_rune_weapon.up|buff.bone_shield.remains<=3)
  if S.Marrowrend:IsReady() and (not Player:BonestormTicking() and (VarBoneShieldStacks < VarBoneShieldRefreshValue and Player:RunicPowerDeficit() > 20 and S.DancingRuneWeapon:CooldownDown() or Player:BuffRemains(S.BoneShieldBuff) <= 3)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend sanlayn 34"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and Target:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper sanlayn 36"; end
  end
  -- death_strike,if=buff.dancing_rune_weapon.up&(buff.coagulopathy.remains<2*gcd|(target.health.pct<variable.death_strike_sang_low_hp&runic_power>50))
  -- death_strike,if=buff.dancing_rune_weapon.up&(buff.coagulopathy.remains<2*gcd|(runic_power.deficit<=variable.heart_strike_rp_drw&debuff.incite_terror.stack>=3))
  if S.DeathStrike:IsReady() and (Player:BuffUp(S.DancingRuneWeaponBuff)) and (
    (Player:BuffRemains(S.CoagulopathyBuff) < 2 * Player:GCD() or (Target:HealthPercentage() < VarDeathStrikeSangLowHP and Player:RunicPower() > 50)) or
    (Player:BuffRemains(S.CoagulopathyBuff) < 2 * Player:GCD() or (Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW and Target:DebuffStack(S.InciteTerrorDebuff) >= 3))
  ) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike sanlayn 38"; end
  end
  -- heart_strike,if=buff.vampiric_strike.up|buff.infliction_of_sorrow.up&((talent.consumption.enabled&buff.consumption.up)|!talent.consumption.enabled)&dot.blood_plague.ticking&dot.blood_plague.remains>20
  if HSAction:IsReady() and (S.VampiricStrikeAction:IsReady() or Player:BuffUp(S.InflictionofSorrowBuff) and ((S.Consumption:IsAvailable() and Player:BuffUp(S.ConsumptionBuff)) or not S.Consumption:IsAvailable()) and Target:DebuffUp(S.BloodPlagueDebuff) and Target:DebuffRemains(S.BloodPlagueDebuff) > 20) then
    if Cast(HSAction, nil, nil, not Target:IsSpellInRange(HSAction)) then return "heart_strike sanlayn 40"; end
  end
  -- dancing_rune_weapon,if=buff.coagulopathy.up
  if CDsON() and S.DancingRuneWeapon:IsCastable() and (Player:BuffUp(S.CoagulopathyBuff)) then
    if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon sanlayn 42"; end
  end
  -- death_strike,if=runic_power.deficit<=variable.heart_strike_rp_drw|runic_power>=variable.death_strike_dump_amount
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW or Player:RunicPower() >= VarDeathStrikeDumpAmt) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike sanlayn 44"; end
  end
  -- blood_boil,if=charges>=2|(full_recharge_time<=gcd.max)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:Charges() >= 2 or (S.BloodBoil:FullRechargeTime() <= Player:GCD())) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil sanlayn 46"; end
  end
  -- consumption,if=cooldown.dancing_rune_weapon.remains>20
  if S.Consumption:IsCastable() and (S.DancingRuneWeapon:CooldownRemains() > 20) then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption sanlayn 48"; end
  end
  -- heart_strike,if=rune>1
  if HSAction:IsReady() and (Player:Rune() > 1) then
    if Cast(HSAction, nil, nil, not Target:IsSpellInRange(HSAction)) then return "heart_strike sanlayn 50"; end
  end
  -- bonestorm,if=buff.death_and_decay.up&buff.bone_shield.stack>5&cooldown.dancing_rune_weapon.remains
  if CDsON() and S.Bonestorm:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and VarBoneShieldStacks > 5 and S.DancingRuneWeapon:CooldownDown()) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm sanlayn 52"; end
  end
  -- tombstone,if=buff.death_and_decay.up&buff.bone_shield.stack>5&runic_power.deficit>=30&cooldown.dancing_rune_weapon.remains
  if S.Tombstone:IsReady() and (Player:BuffUp(S.DeathAndDecayBuff) and VarBoneShieldStacks > 5 and Player:RunicPowerDeficit() >= 30 and S.DancingRuneWeapon:CooldownDown()) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone sanlayn 54"; end
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

    -- Heart Strike or Vampiric Strike?
    HSAction = S.VampiricStrikeAction:IsReady() and S.VampiricStrikeAction or S.HeartStrike
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
    -- restart_sequence,name=drw_bp,if=cooldown.dancing_rune_weapon.remains<10
    -- Note: Used by Simulationcraft, but unnecessary here.
    -- use_item,name=tome_of_lights_devotion,if=buff.inner_resilience.up
    if I.TomeofLightsDevotion:IsEquippedAndReady() and Player:BuffUp(S.InnerResilienceBuff) then
      if Cast(I.TomeofLightsDevotion, Settings.CommonsDS.DisplayStyle.Trinkets) then return "tome_of_lights_devotion main 2"; end
    end
    -- use_items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "use_items ("..ItemToUse:Name()..") main 4"; end
        end
      end
    end
    if Player:BuffUp(S.DancingRuneWeaponBuff) then
      if CDsON() then
        -- blood_fury,if=buff.dancing_rune_weapon.up
        if S.BloodFury:IsCastable() then
          if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 6"; end
        end
        -- berserking,if=buff.dancing_rune_weapon.up
        if S.Berserking:IsCastable() then
          if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 8"; end
        end
        -- ancestral_call,if=buff.dancing_rune_weapon.up
        if S.AncestralCall:IsCastable() then
          if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 10"; end
        end
        -- fireblood,if=buff.dancing_rune_weapon.up
        if S.Fireblood:IsCastable() then
          if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 12"; end
        end
      end
      -- potion,if=buff.dancing_rune_weapon.up
      if Settings.Commons.Enabled.Potions then
        local PotionSelected = Everyone.PotionSelected()
        if PotionSelected and PotionSelected:IsReady() then
          if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 14"; end
        end
      end
    end
    -- vampiric_blood,if=!buff.vampiric_blood.up
    -- Note: Handled in Defensives()
    -- raise_dead
    if CDsON() and S.RaiseDead:IsCastable() then
      if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead main 16"; end
    end
    -- blood_tap,if=(rune<=2&rune.time_to_3>gcd&charges_fractional>=1.8)
    -- blood_tap,if=(rune<=1&rune.time_to_3>gcd)
    if CDsON() and S.BloodTap:IsCastable() and (
      (Player:Rune() <= 2 and Player:RuneTimeToX(3) > Player:GCD() and S.BloodTap:ChargesFractional() >= 1.8) or
      (Player:Rune() <= 1 and Player:RuneTimeToX(3) > Player:GCD())
    ) then
      if Cast(S.BloodTap, Settings.Blood.OffGCDasOffGCD.BloodTap) then return "blood_tap main 18"; end
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

  HR.Print("Blood Death Knight rotation has been updated for patch 11.1.0.")
end

HR.SetAPL(250, APL, Init)
