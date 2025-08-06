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
  I.BestinSlots:ID(),
  I.TomeofLightsDevotion:ID(),
  I.UnyieldingNetherprism:ID(),
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
local VarRPDeficitThreshold
local IsTanking
local TargetInMeleeRange
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
  -- snapshot_stats
  -- deaths_caress
  if S.DeathsCaress:IsReady() then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress precombat 2"; end
  end
  -- Manually added: marrowrend
  if S.Marrowrend:IsReady() then
    if Cast(S.Marrowrend, nil, nil, not TargetInMeleeRange) then return "marrowrend precombat 4"; end
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
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike defensives 4"; end
    end
    if S.Marrowrend:IsReady() then
      if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend defensives 6"; end
    end
    if S.DeathStrike:IsReady() then
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike defensives 8"; end
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
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike defensives 14"; end
  end
end

local function HighPrioActions()
  -- raise_dead,use_off_gcd=1
  if CDsON() and S.RaiseDead:IsCastable() then
    if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead high_prio_actions 2"; end
  end
  -- blood_tap,if=(rune<=2&rune.time_to_3>gcd&charges_fractional>=1.8)
  -- blood_tap,if=(rune<=1&rune.time_to_3>gcd)
  if CDsON() and S.BloodTap:IsCastable() and (
    (Player:Rune() <= 2 and Player:RuneTimeToX(3) > Player:GCD() and S.BloodTap:ChargesFractional() >= 1.8) or
    (Player:Rune() <= 1 and Player:RuneTimeToX(3) > Player:GCD())
  ) then
    if Cast(S.BloodTap, Settings.Blood.OffGCDasOffGCD.BloodTap) then return "blood_tap high_prio_actions 4"; end
  end
  -- death_strike,if=buff.coagulopathy.up&buff.coagulopathy.remains<=gcd
  if S.DeathStrike:IsReady() and (Player:BuffUp(S.CoagulopathyBuff) and Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD()) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike high_prio_actions 6"; end
  end
  -- dancing_rune_weapon
  if S.DancingRuneWeapon:IsCastable() then
    if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon high_prio_actions 8"; end
  end
end

local function Deathbringer()
  -- rune_tap,if=rune>4
  -- Note: Handled in Defensives().
  -- bonestorm,if=buff.bone_shield.stack>=5&buff.death_and_decay.remains
  if S.Bonestorm:IsReady() and (VarBoneShieldStacks >= 5 and Player:BuffUp(S.DeathAndDecayBuff)) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm deathbringer 2"; end
  end
  -- death_strike,if=(runic_power.deficit<20|(runic_power.deficit<26&buff.dancing_rune_weapon.up))
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() < 20 or (Player:RunicPowerDeficit() < 26 and Player:BuffUpS(S.DancingRuneWeaponBuff))) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike deathbringer 4"; end
  end
  -- soul_reaper,if=active_enemies<=2&buff.reaper_of_souls.up&target.time_to_die>(dot.soul_reaper.remains+5)
  -- soul_reaper,if=active_enemies<=2&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  -- Note: Combining both lines.
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount <= 2 and (Player:BuffUp(S.ReaperofSoulsBuff) or Target:TimeToX(35) < 5) and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not TargetInMeleeRange) then return "soul_reaper deathbringer 6"; end
  end
  -- reapers_mark
  if S.ReapersMark:IsReady() then
    if Cast(S.ReapersMark, nil, nil, not TargetInMeleeRange) then return "reapers_mark deathbringer 8"; end
  end
  -- blood_boil,if=buff.dancing_rune_weapon.up&!drw.bp_ticking
  if S.BloodBoil:IsCastable() and (Player:BuffUp(S.DancingRuneWeaponBuff) and not Player:DRWBPTicking()) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 10"; end
  end
  -- death_and_decay,if=!buff.death_and_decay.up
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff)) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay deathbringer 12"; end
  end
  -- marrowrend,if=buff.exterminate.up|(buff.bone_shield.stack<5&!dot.bonestorm.ticking)
  if S.Marrowrend:IsReady() and (Player:BuffUp(S.ExterminateBuff) or (VarBoneShieldStacks < 5 and not Player:BonestormTicking())) then
    if Cast(S.Marrowrend, nil, nil, not TargetInMeleeRange) then return "marrowrend deathbringer 14"; end
  end
  -- death_strike
  if S.DeathStrike:IsReady() then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike deathbringer 16"; end
  end
  -- tombstone,if=buff.bone_shield.stack>=8&buff.death_and_decay.remains&cooldown.dancing_rune_weapon.remains>=25
  if S.Tombstone:IsReady() and (VarBoneShieldStacks >= 8 and Player:BuffUp(S.DeathAndDecayBuff) and S.DancingRuneWeapon:CooldownRemains() >= 25) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone deathbringer 18"; end
  end
  -- blooddrinker,if=!buff.dancing_rune_weapon.up&active_enemies<=2&buff.coagulopathy.remains>3
  if S.Blooddrinker:IsReady() and (Player:BuffDown(S.DancingRuneWeaponBuff) and EnemiesMeleeCount <= 2 and Player:BuffRemains(S.CoagulopathyBuff) > 3) then
    if Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker deathbringer 20"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not TargetInMeleeRange) then return "consumption deathbringer 22"; end
  end
  -- blood_boil
  if S.BloodBoil:IsCastable() then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil deathbringer 24"; end
  end
  -- heart_strike,if=buff.coagulopathy.stack<5
  if HSAction:IsReady() and (Player:BuffStack(S.CoagulopathyBuff) < 5) then
    if Cast(S.HeartStrike, nil, nil, not TargetInMeleeRange) then return "heart_strike deathbringer 26"; end
  end
  -- heart_strike
  if HSAction:IsReady() then
    if Cast(S.HeartStrike, nil, nil, not TargetInMeleeRange) then return "heart_strike deathbringer 28"; end
  end
  -- soul_reaper,if=buff.reaper_of_souls.up
  if S.SoulReaper:IsReady() and (Player:BuffUp(S.ReaperofSoulsBuff) and S.DancingRuneWeapon:CooldownDown()) then
    if Cast(S.SoulReaper, nil, nil, not TargetInMeleeRange) then return "soul_reaper deathbringer 30"; end
  end
  -- arcane_torrent,if=runic_power.deficit>20
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 20) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent deathbringer 32"; end
  end
end

local function SanDRW()
  -- heart_strike,if=buff.essence_of_the_blood_queen.remains<1.5&buff.essence_of_the_blood_queen.remains
  if HSAction:IsReady() and (Player:BuffRemains(S.EssenceoftheBloodQueenBuff) < 1.5 and Player:BuffUp(S.EssenceoftheBloodQueenBuff)) then
    if Cast(HSAction, nil, nil, not TargetInMeleeRange) then return "heart_strike san_drw 2"; end
  end
  -- bonestorm,if=buff.bone_shield.stack>=5&buff.death_and_decay.remains
  if S.Bonestorm:IsReady() and (VarBoneShieldStacks >= 5 and Player:BuffUp(S.DeathAndDecayBuff)) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm san_drw 4"; end
  end
  -- death_strike,if=runic_power.deficit<36
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() < 36) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike san_drw 6"; end
  end
  -- blood_boil,if=!drw.bp_ticking
  if S.BloodBoil:IsCastable() and (not Player:DRWBPTicking()) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil san_drw 8"; end
  end
  -- any_dnd,if=(active_enemies<=3&buff.crimson_scourge.remains)|(active_enemies>3&!buff.death_and_decay.remains)
  if S.DeathAndDecay:IsReady() and ((EnemiesMeleeCount <= 3 and Player:BuffUp(S.CrimsonScourgeBuff)) or (EnemiesMeleeCount > 3 and Player:BuffDown(S.DeathAndDecayBuff))) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay) then return "death_and_decay san_drw 10"; end
  end
  -- heart_strike
  if HSAction:IsReady() then
    if Cast(HSAction, nil, nil, not TargetInMeleeRange) then return "heart_strike san_drw 12"; end
  end
  -- death_strike
  if S.DeathStrike:IsReady() then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike san_drw 14"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not TargetInMeleeRange) then return "consumption san_drw 16"; end
  end
  -- blood_boil
  if S.BloodBoil:IsCastable() then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil san_drw 18"; end
  end
end

local function Sanlayn()
  -- blood_boil,if=(!buff.bone_shield.up|buff.bone_shield.remains<1.5|buff.bone_shield.stack<=1)&active_enemies>=2
  if S.BloodBoil:IsReady() and ((Player:BuffDown(S.BoneShieldBuff) or Player:BuffRemains(S.BoneShieldBuff) < 1.5 or Player:BuffStack(S.BoneShieldBuff) <= 1) and EnemiesMeleeCount >= 2) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil) then return "blood_boil sanlayn 2"; end
  end
  -- deaths_caress,if=!buff.bone_shield.up|buff.bone_shield.remains<1.5|buff.bone_shield.stack<=1
  if S.DeathsCaress:IsReady() and (Player:BuffDown(S.BoneShieldBuff) or Player:BuffRemains(S.BoneShieldBuff) < 1.5 or Player:BuffStack(S.BoneShieldBuff) <= 1) then
    if Cast(S.DeathsCaress, Settings.Blood.GCDasOffGCD.DeathsCaress) then return "deaths_caress sanlayn 4"; end
  end
  -- blood_boil,if=dot.blood_plague.remains<3
  if S.BloodBoil:IsReady() and (Player:BuffRemains(S.BloodPlagueDebuff) < 3) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil) then return "blood_boil sanlayn 6"; end
  end
  -- heart_strike,if=(buff.essence_of_the_blood_queen.remains<1.5&buff.essence_of_the_blood_queen.remains&buff.vampiric_strike.remains)
  if HSAction:IsReady() and (Player:BuffRemains(S.EssenceoftheBloodQueenBuff) < 1.5 and Player:BuffUp(S.EssenceoftheBloodQueenBuff) and Player:BuffUp(S.VampiricStrikeBuff)) then
    if Cast(HSAction, nil, nil, not TargetInMeleeRange) then return "heart_strike sanlayn 8"; end
  end
  -- bonestorm,if=buff.bone_shield.stack>=5&buff.death_and_decay.remains
  if S.Bonestorm:IsReady() and (VarBoneShieldStacks >= 5 and Player:BuffUp(S.DeathAndDecayBuff)) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm sanlayn 10"; end
  end
  -- death_strike,if=runic_power.deficit<20
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() < 20) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike sanlayn 12"; end
  end
  -- consumption,if=buff.infliction_of_sorrow.up&buff.death_and_decay.up
  if S.Consumption:IsReady() and (Player:BuffUp(S.InflictionofSorrowBuff) and Player:BuffUp(S.DeathAndDecayBuff)) then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not TargetInMeleeRange) then return "consumption sanlayn 14"; end
  end
  -- heart_strike,if=(buff.infliction_of_sorrow.up|buff.vampiric_strike.up)&buff.death_and_decay.up
  if HSAction:IsReady() and ((Player:BuffUp(S.InflictionofSorrowBuff) or Player:BuffUp(S.VampiricStrikeBuff)) and Player:BuffUp(S.DeathAndDecayBuff)) then
    if Cast(HSAction, nil, nil, not TargetInMeleeRange) then return "heart_strike sanlayn 16"; end
  end
  -- soul_reaper,if=active_enemies<=2&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount <= 2 and Player:TimeToX(35) < 5 and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not TargetInMeleeRange) then return "soul_reaper sanlayn 18"; end
  end
  -- blood_boil,if=buff.bone_shield.stack<6&!dot.bonestorm.ticking&active_enemies>=2
  if S.BloodBoil:IsReady() and (VarBoneShieldStacks < 6 and not Player:BonestormTicking() and EnemiesMeleeCount >= 2) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil) then return "blood_boil sanlayn 20"; end
  end
  -- deaths_caress,if=buff.bone_shield.stack<6&!dot.bonestorm.ticking
  if S.DeathsCaress:IsReady() and (VarBoneShieldStacks < 6 and not Player:BonestormTicking()) then
    if Cast(S.DeathsCaress, Settings.Blood.GCDasOffGCD.DeathsCaress) then return "deaths_caress sanlayn 22"; end
  end
  -- marrowrend,if=buff.bone_shield.stack<6&!dot.bonestorm.ticking
  if S.Marrowrend:IsReady() and (VarBoneShieldStacks < 6 and not Player:BonestormTicking()) then
    if Cast(S.Marrowrend, nil, nil, not TargetInMeleeRange) then return "marrowrend sanlayn 24"; end
  end
  -- tombstone,if=buff.bone_shield.stack>=6&buff.death_and_decay.remains&cooldown.dancing_rune_weapon.remains>=25
  if S.Tombstone:IsReady() and (VarBoneShieldStacks >= 6 and Player:BuffUp(S.DeathAndDecayBuff) and S.DancingRuneWeapon:CooldownRemains() >= 25) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone sanlayn 26"; end
  end
  -- any_dnd,if=(active_enemies<=3&buff.crimson_scourge.remains)|(active_enemies>3&!buff.death_and_decay.remains)
  if S.DeathAndDecay:IsReady() and ((EnemiesMeleeCount <= 3 and Player:BuffUp(S.CrimsonScourgeBuff)) or (EnemiesMeleeCount > 3 and Player:BuffDown(S.DeathAndDecayBuff))) then
    if Cast(S.DeathAndDecay, Settings.Blood.GCDasOffGCD.DeathAndDecay) then return "death_and_decay sanlayn 28"; end
  end
  -- blooddrinker,if=active_enemies<=2&buff.coagulopathy.remains>3
  if S.Blooddrinker:IsReady() and (EnemiesMeleeCount <= 2 and Player:BuffRemains(S.CoagulopathyBuff) > 3) then
    if Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker sanlayn 30"; end
  end
  -- heart_strike,if=buff.vampiric_strike.up
  if S.VampiricStrikeAction:IsReady() then
    if Cast(S.VampiricStrikeAction, nil, nil, not TargetInMeleeRange) then return "heart_strike sanlayn 32"; end
  end
  -- death_strike
  if S.DeathStrike:IsReady() then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not TargetInMeleeRange) then return "death_strike sanlayn 34"; end
  end
  -- heart_strike,if=rune>=2
  if HSAction:IsReady() and (Player:Rune() >= 2) then
    if Cast(HSAction, nil, nil, not TargetInMeleeRange) then return "heart_strike sanlayn 36"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not TargetInMeleeRange) then return "consumption sanlayn 38"; end
  end
  -- blood_boil
  if S.BloodBoil:IsCastable() then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil) then return "blood_boil sanlayn 40"; end
  end
  -- heart_strike
  if HSAction:IsReady() then
    if Cast(HSAction, nil, nil, not TargetInMeleeRange) then return "heart_strike sanlayn 42"; end
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

    -- Target in melee range?
    TargetInMeleeRange = Target:IsSpellInRange(S.DeathStrike)

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
    -- use_item,name=tome_of_lights_devotion,if=buff.inner_resilience.up,use_off_gcd=1
    if I.TomeofLightsDevotion:IsEquippedAndReady() and Player:BuffUp(S.InnerResilienceBuff) then
      if Cast(I.TomeofLightsDevotion, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "tome_of_lights_devotion main 2"; end
    end
    -- use_item,name=unyielding_netherprism,if=cooldown.dancing_rune_weapon.remains<1|target.time_to_die<=20,use_off_gcd=1
    if I.UnyieldingNetherprism:IsEquippedAndReady() and (S.DancingRuneWeapon:CooldownRemains() < 1 or Target:TimeToDie() <= 20) then
      if Cast(I.UnyieldingNetherprism, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "unyielding_netherprism main 4"; end
    end
    -- use_items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "use_items ("..ItemToUse:Name()..") main 6"; end
        end
      end
    end
    -- use_item,name=bestinslots,use_off_gcd=1
    if I.BestinSlots:IsEquippedAndReady() then
      if Cast(I.BestinSlots, nil, Settings.CommonsDS.DisplayStyle.Items) then return "bestinslots main 4"; end
    end
    if Player:BuffUp(S.DancingRuneWeaponBuff) then
      if CDsON() then
        -- blood_fury,if=buff.dancing_rune_weapon.up
        if S.BloodFury:IsCastable() then
          if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 8"; end
        end
        -- berserking,if=buff.dancing_rune_weapon.up
        if S.Berserking:IsCastable() then
          if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 10"; end
        end
        -- ancestral_call,if=buff.dancing_rune_weapon.up
        if S.AncestralCall:IsCastable() then
          if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 12"; end
        end
        -- fireblood,if=buff.dancing_rune_weapon.up
        if S.Fireblood:IsCastable() then
          if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 14"; end
        end
      end
      -- potion,if=buff.dancing_rune_weapon.up
      if Settings.Commons.Enabled.Potions then
        local PotionSelected = Everyone.PotionSelected()
        if PotionSelected and PotionSelected:IsReady() then
          if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 16"; end
        end
      end
    end
    -- vampiric_blood,if=!buff.vampiric_blood.up
    -- Note: Handled in Defensives()
    -- call_action_list,name=high_prio_actions
    local ShouldReturn = HighPrioActions(); if ShouldReturn then return ShouldReturn; end
    -- run_action_list,name=deathbringer,if=hero_tree.deathbringer
    if Player:HeroTreeID() == 33 or Player:Level() <= 70 then
      local ShouldReturn = Deathbringer(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Deathbringer()"; end
    end
    -- run_action_list,name=san_drw,if=hero_tree.sanlayn&buff.dancing_rune_weapon.up
    if Player:HeroTreeID() == 31 and Player:BuffUp(S.DancingRuneWeaponBuff) then
      local ShouldReturn = SanDRW(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SanDRW()"; end
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

  HR.Print("Blood Death Knight rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(250, APL, Init)
