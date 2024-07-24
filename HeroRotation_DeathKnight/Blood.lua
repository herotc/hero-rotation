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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Blood
local I = Item.DeathKnight.Blood

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.Fyralath:ID(),
}

-- Rotation Var
local VarDeathStrikeDumpAmt = 65
local VarBoneShieldRefreshValue = (not S.DeathsCaress:IsAvailable() or S.Consumption:IsAvailable() or S.Blooddrinker:IsAvailable()) and 4 or 5
local VarHeartStrikeRP = 0
local VarHeartStrikeRPDRW = 0
local IsTanking
local EnemiesMelee
local EnemiesMeleeCount
local HeartStrikeCount
local UnitsWithoutBloodPlague
local Ghoul = HL.GhoulTable

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  CommonsDS = HR.GUISettings.APL.DeathKnight.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.DeathKnight.CommonsOGCD,
  Blood = HR.GUISettings.APL.DeathKnight.Blood
}

-- Stun Interrupts List
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
}

-- Register for talent changes
HL:RegisterForEvent(function()
  VarBoneShieldRefreshValue = (not S.DeathsCaress:IsAvailable() or S.Consumption:IsAvailable() or S.Blooddrinker:IsAvailable()) and 4 or 5
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--Functions
local function UnitsWithoutBP(enemies)
  local WithoutBPCount = 0
  for _, CycleUnit in pairs(enemies) do
    if not CycleUnit:DebuffUp(S.BloodPlagueDebuff) then
      WithoutBPCount = WithoutBPCount + 1
    end
  end
  return WithoutBPCount
end

-- Functions for CastTargetIf
local function EvaluateTargetIfFilterSoulReaper(TargetUnit)
  -- target_if=min:dot.soul_reaper.remains
  return (TargetUnit:DebuffRemains(S.SoulReaperDebuff))
end

local function EvaluateTargetIfSoulReaper(TargetUnit)
  -- if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  return ((TargetUnit:TimeToX(35) < 5 or TargetUnit:HealthPercentage() <= 35) and TargetUnit:TimeToDie() > (TargetUnit:DebuffRemains(S.SoulReaperDebuff) + 5))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit)|trinket.1.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit)|trinket.2.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl|variable.trinket_1_buffs
  -- Note: Can't handle checking for specific stat buffs.
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
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 10"; end
    end
  end
  -- Vampiric Blood
  if S.VampiricBlood:IsCastable() and IsTanking and Player:HealthPercentage() <= Settings.Blood.VampiricBloodThreshold and Player:BuffDown(S.IceboundFortitudeBuff) then
    if Cast(S.VampiricBlood, Settings.Blood.GCDasOffGCD.VampiricBlood) then return "vampiric_blood defensives 14"; end
  end
  -- Icebound Fortitude
  if S.IceboundFortitude:IsCastable() and IsTanking and Player:HealthPercentage() <= Settings.Blood.IceboundFortitudeThreshold and Player:BuffDown(S.VampiricBloodBuff) then
    if Cast(S.IceboundFortitude, Settings.Blood.GCDasOffGCD.IceboundFortitude) then return "icebound_fortitude defensives 16"; end
  end
  -- Healing
  if S.DeathStrike:IsReady() and Player:HealthPercentage() <= 50 + (Player:RunicPower() > VarDeathStrikeDumpAmt and 20 or 0) and not Player:HealingAbsorbed() then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 18"; end
  end
end

local function DRWUp()
  -- blood_boil,if=!dot.blood_plague.ticking
  if S.BloodBoil:IsReady() and (Target:DebuffDown(S.BloodPlagueDebuff)) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil drw_up 2"; end
  end
  -- tombstone,if=buff.bone_shield.stack>5&rune>=2&runic_power.deficit>=30&!talent.shattering_bone|(talent.shattering_bone.enabled&death_and_decay.ticking)
  if S.Tombstone:IsReady() and (Player:BuffStack(S.BoneShieldBuff) > 5 and Player:Rune() >= 2 and Player:RunicPowerDeficit() >= 30 and (not S.ShatteringBone:IsAvailable() or (S.ShatteringBone:IsAvailable() and Player:BuffUp(S.DeathAndDecayBuff)))) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone drw_up 4"; end
  end
  -- death_strike,if=buff.coagulopathy.remains<=gcd|buff.icy_talons.remains<=gcd
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD() or Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD()) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsInMeleeRange(5)) then return "death_strike drw_up 6"; end
  end
  -- marrowrend,if=(buff.bone_shield.remains<=4|buff.bone_shield.stack<variable.bone_shield_refresh_value)&runic_power.deficit>20
  if S.Marrowrend:IsReady() and ((Player:BuffRemains(S.BoneShieldBuff) <= 4 or Player:BuffStack(S.BoneShieldBuff) < VarBoneShieldRefreshValue) and Player:RunicPowerDeficit() > 20) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend drw_up 10"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and (Target:TimeToX(35) < 5 or Target:HealthPercentage() <= 35) and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper drw_up 12"; end
  end
  -- soul_reaper,target_if=min:dot.soul_reaper.remains,if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount >= 2) then
    if Everyone.CastTargetIf(S.SoulReaper, EnemiesMelee, "min", EvaluateTargetIfFilterSoulReaper, EvaluateTargetIfSoulReaper, not Target:IsInMeleeRange(5)) then return "soul_reaper drw_up 14"; end
  end
  -- death_and_decay,if=!death_and_decay.ticking&(talent.sanguine_ground|talent.unholy_ground)
  if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (S.SanguineGround:IsAvailable() or S.UnholyGround:IsAvailable())) then
    if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay, nil, not Target:IsInRange(30)) then return "death_and_decay drw_up 16"; end
  end
  -- blood_boil,if=spell_targets.blood_boil>2&charges_fractional>=1.1
  if S.BloodBoil:IsCastable() and (EnemiesMeleeCount > 2 and S.BloodBoil:ChargesFractional() >= 1.1) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil drw_up 18"; end
  end
  -- variable,name=heart_strike_rp_drw,value=(25+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRPDRW = (25 + HeartStrikeCount * num(S.Heartbreaker:IsAvailable()) * 2)
  -- death_strike,if=runic_power.deficit<=variable.heart_strike_rp_drw|runic_power>=variable.death_strike_dump_amount
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= VarHeartStrikeRPDRW or Player:RunicPower() >= VarDeathStrikeDumpAmt) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike drw_up 20"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption drw_up 22"; end
  end
  -- blood_boil,if=charges_fractional>=1.1&buff.hemostasis.stack<5
  if S.BloodBoil:IsReady() and (S.BloodBoil:ChargesFractional() >= 1.1 and Player:BuffStack(S.HemostasisBuff) < 5) then
    if Cast(S.BloodBoil, nil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil drw_up 24"; end
  end
  -- heart_strike,if=rune.time_to_2<gcd|runic_power.deficit>=variable.heart_strike_rp_drw
  if S.HeartStrike:IsReady() and (Player:RuneTimeToX(2) < Player:GCD() or Player:RunicPowerDeficit() >= VarHeartStrikeRPDRW) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike drw_up 26"; end
  end
end

local function Racials()
  -- blood_fury,if=cooldown.dancing_rune_weapon.ready&(!cooldown.blooddrinker.ready|!talent.blooddrinker.enabled)
  if S.BloodFury:IsCastable() and (S.DancingRuneWeapon:CooldownUp() and (not S.Blooddrinker:IsReady() or not S.Blooddrinker:IsAvailable()))  then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury racials 2"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking racials 4"; end
  end
  -- arcane_pulse,if=active_enemies>=2|rune<1&runic_power.deficit>60
  if S.ArcanePulse:IsCastable() and (EnemiesMeleeCount >= 2 or Player:Rune() < 1 and Player:RunicPowerDeficit() > 60) then
    if Cast(S.ArcanePulse, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse racials 6"; end
  end
  -- lights_judgment,if=buff.unholy_strength.up
  if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff)) then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment racials 8"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call racials 10"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood racials 12"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks racials 14"; end
  end
  -- arcane_torrent,if=runic_power.deficit>20
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 20) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent racials 16"; end
  end
end

local function Standard()
  -- tombstone,if=buff.bone_shield.stack>5&rune>=2&runic_power.deficit>=30&!talent.shattering_bone|(talent.shattering_bone.enabled&death_and_decay.ticking)&cooldown.dancing_rune_weapon.remains>=25
  if CDsON() and S.Tombstone:IsCastable() and (Player:BuffStack(S.BoneShieldBuff) > 5 and Player:Rune() >= 2 and Player:RunicPowerDeficit() >= 30 and (not S.ShatteringBone:IsAvailable() or (S.ShatteringBone:IsAvailable() and Player:BuffUp(S.DeathAndDecayBuff))) and S.DancingRuneWeapon:CooldownRemains() >= 25) then
    if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone standard 2"; end
  end
  -- variable,name=heart_strike_rp,value=(10+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  VarHeartStrikeRP = (10 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2)
  -- death_strike,if=buff.coagulopathy.remains<=gcd|buff.icy_talons.remains<=gcd|runic_power>=variable.death_strike_dump_amount|runic_power.deficit<=variable.heart_strike_rp|target.time_to_die<10
  if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD() or Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD() or Player:RunicPower() >= VarDeathStrikeDumpAmt or Player:RunicPowerDeficit() <= VarHeartStrikeRP or Target:TimeToDie() < 10) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsInMeleeRange(5)) then return "death_strike standard 4"; end
  end
  -- deaths_caress,if=(buff.bone_shield.remains<=4|(buff.bone_shield.stack<variable.bone_shield_refresh_value+1))&runic_power.deficit>10&!(talent.insatiable_blade&cooldown.dancing_rune_weapon.remains<buff.bone_shield.remains)&!talent.consumption.enabled&!talent.blooddrinker.enabled&rune.time_to_3>gcd
  if S.DeathsCaress:IsReady() and ((Player:BuffRemains(S.BoneShieldBuff) <= 4 or (Player:BuffStack(S.BoneShieldBuff) < VarBoneShieldRefreshValue + 1)) and Player:RunicPowerDeficit() > 10 and (not (S.InsatiableBlade:IsAvailable() and S.DancingRuneWeapon:CooldownRemains() < Player:BuffRemains(S.BoneShieldBuff))) and not S.Consumption:IsAvailable() and not S.Blooddrinker:IsAvailable() and Player:RuneTimeToX(3) > Player:GCD()) then
    if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress standard 6"; end
  end
  -- marrowrend,if=(buff.bone_shield.remains<=4|buff.bone_shield.stack<variable.bone_shield_refresh_value)&runic_power.deficit>20&!(talent.insatiable_blade&cooldown.dancing_rune_weapon.remains<buff.bone_shield.remains)
  if S.Marrowrend:IsReady() and ((Player:BuffRemains(S.BoneShieldBuff) <= 4 or Player:BuffStack(S.BoneShieldBuff) < VarBoneShieldRefreshValue) and Player:RunicPowerDeficit() > 20 and not (S.InsatiableBlade:IsAvailable() and S.DancingRuneWeapon:CooldownRemains() < Player:BuffRemains(S.BoneShieldBuff))) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsInMeleeRange(5)) then return "marrowrend standard 8"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption standard 10"; end
  end
  -- soul_reaper,if=active_enemies=1&target.time_to_pct_35<5&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount == 1 and (Target:TimeToX(35) < 5 or Target:HealthPercentage() <= 35) and Target:TimeToDie() > (Target:DebuffRemains(S.SoulReaperDebuff) + 5)) then
    if Cast(S.SoulReaper, nil, nil, not Target:IsInMeleeRange(5)) then return "soul_reaper standard 12"; end
  end
  -- soul_reaper,target_if=min:dot.soul_reaper.remains,if=target.time_to_pct_35<5&active_enemies>=2&target.time_to_die>(dot.soul_reaper.remains+5)
  if S.SoulReaper:IsReady() and (EnemiesMeleeCount >= 2) then
    if Everyone.CastTargetIf(S.SoulReaper, EnemiesMelee, "min", EvaluateTargetIfFilterSoulReaper, EvaluateTargetIfSoulReaper, not Target:IsInMeleeRange(5)) then return "soul_reaper standard 14"; end
  end
  -- bonestorm,if=runic_power>=100
  if CDsON() and S.Bonestorm:IsReady() and (Player:RunicPower() >= 100) then
    if Cast(S.Bonestorm, Settings.Blood.GCDasOffGCD.Bonestorm, nil, not Target:IsInMeleeRange(8)) then return "bonestorm standard 16"; end
  end
  -- blood_boil,if=charges_fractional>=1.8&(buff.hemostasis.stack<=(5-spell_targets.blood_boil)|spell_targets.blood_boil>2)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.8 and (Player:BuffStack(S.HemostasisBuff) <= (5 - EnemiesMeleeCount) or EnemiesMeleeCount > 2)) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil standard 18"; end
  end
  -- heart_strike,if=rune.time_to_4<gcd
  if S.HeartStrike:IsReady() and (Player:RuneTimeToX(4) < Player:GCD()) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike standard 20"; end
  end
  -- blood_boil,if=charges_fractional>=1.1
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.1) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil standard 22"; end
  end
  -- heart_strike,if=(rune>1&(rune.time_to_3<gcd|buff.bone_shield.stack>7))
  if S.HeartStrike:IsReady() and (Player:Rune() > 1 and (Player:RuneTimeToX(3) < Player:GCD() or Player:BuffStack(S.BoneShieldBuff) > 7)) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike standard 24"; end
  end
end

local function Trinkets()
  -- use_item,name=fyralath_the_dreamrender,if=dot.mark_of_fyralath.ticking
  if Settings.Commons.Enabled.Items and I.Fyralath:IsEquippedAndReady() and (S.MarkofFyralathDebuff:AuraActiveCount() > 0) then
    if Cast(I.Fyralath, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(25)) then return "fyralath_the_dreamrender trinkets 2"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|!trinket.2.has_cooldown)
  -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|!trinket.1.has_cooldown)
  -- use_item,use_off_gcd=1,slot=main_hand,if=!equipped.fyralath_the_dreamrender&(variable.trinket_1_buffs|trinket.1.cooldown.remains)&(variable.trinket_2_buffs|trinket.2.cooldown.remains)
  -- use_item,use_off_gcd=1,slot=trinket1,if=variable.trinket_1_buffs&(buff.dancing_rune_weapon.up|!talent.dancing_rune_weapon|cooldown.dancing_rune_weapon.remains>20)&(variable.trinket_2_exclude|trinket.2.cooldown.remains|!trinket.2.has_cooldown|variable.trinket_2_buffs)
  -- use_item,use_off_gcd=1,slot=trinket2,if=variable.trinket_2_buffs&(buff.dancing_rune_weapon.up|!talent.dancing_rune_weapon|cooldown.dancing_rune_weapon.remains>20)&(variable.trinket_1_exclude|trinket.1.cooldown.remains|!trinket.1.has_cooldown|variable.trinket_1_buffs)
  -- Note: Can't handle trinket stat buff checking, so using a generic trinket call
  -- use_items,if=(buff.dancing_rune_weapon.up|!talent.dancing_rune_weapon|cooldown.dancing_rune_weapon.remains>20)
  if (Player:BuffUp(S.DancingRuneWeaponBuff) or not S.DancingRuneWeapon:IsAvailable() or S.DancingRuneWeapon:CooldownRemains() > 20) then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
end

--- ======= ACTION LISTS =======
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
    -- variable,name=death_strike_dump_amount,value=65
    -- Note: Added a slider option, set to 65 as a default.
    VarDeathStrikeDumpAmt = Settings.Blood.DeathStrikeDumpAmount
    -- variable,name=bone_shield_refresh_value,value=4,op=setif,condition=!talent.deaths_caress.enabled|talent.consumption.enabled|talent.blooddrinker.enabled,value_else=5
    -- Moved to variable declarations and PLAYER_TALENT_UPDATE registration. No need to keep checking during combat, as talents can't change at that point.
    -- mind_freeze,if=target.debuff.casting.react
    -- Note: Handled above in Interrupts
    -- invoke_external_buff,name=power_infusion,if=buff.dancing_rune_weapon.up|!talent.dancing_rune_weapon
    -- Note: Not handling external buffs
    -- potion,if=buff.dancing_rune_weapon.up
    if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.DancingRuneWeaponBuff)) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- raise_dead
    if CDsON() and S.RaiseDead:IsCastable() then
      if Cast(S.RaiseDead, nil, Settings.CommonsDS.DisplayStyle.RaiseDead) then return "raise_dead main 4"; end
    end
    -- icebound_fortitude,if=!(buff.dancing_rune_weapon.up|buff.vampiric_blood.up)&(target.cooldown.pause_action.remains>=8|target.cooldown.pause_action.duration>0)
    -- Above Above lines handled via Defensives()
    -- vampiric_blood,if=!buff.vampiric_blood.up&!buff.vampiric_strength.up
    -- Note: Handling this vampiric_blood here, as it's used as an offensive CD with T30P4.
    if S.VampiricBlood:IsCastable() and (Player:BuffDown(S.VampiricBloodBuff) and Player:BuffDown(S.VampiricStrengthBuff) and Player:HasTier(30, 4)) then
      if Cast(S.VampiricBlood, Settings.Blood.GCDasOffGCD.VampiricBlood) then return "vampiric_blood main 5"; end
    end
    -- vampiric_blood,if=!(buff.dancing_rune_weapon.up|buff.icebound_fortitude.up|buff.vampiric_blood.up|buff.vampiric_strength.up)&(target.cooldown.pause_action.remains>=13|target.cooldown.pause_action.duration>0)
    -- Above Above lines handled via Defensives()
    -- deaths_caress,if=!buff.bone_shield.up
    if S.DeathsCaress:IsReady() and (Player:BuffDown(S.BoneShieldBuff)) then
      if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress main 6"; end
    end
    -- death_and_decay,if=!death_and_decay.ticking&(talent.unholy_ground|talent.sanguine_ground|spell_targets.death_and_decay>3|buff.crimson_scourge.up)
    if S.DeathAndDecay:IsReady() and (Player:BuffDown(S.DeathAndDecayBuff) and (S.UnholyGround:IsAvailable() or S.SanguineGround:IsAvailable() or EnemiesMeleeCount > 3 or Player:BuffUp(S.CrimsonScourgeBuff))) then
      if Cast(S.DeathAndDecay, Settings.CommonsOGCD.GCDasOffGCD.DeathAndDecay, nil, not Target:IsInRange(30)) then return "death_and_decay main 8"; end
    end
    -- death_strike,if=buff.coagulopathy.remains<=gcd|buff.icy_talons.remains<=gcd|runic_power>=variable.death_strike_dump_amount|runic_power.deficit<=variable.heart_strike_rp|target.time_to_die<10
    if S.DeathStrike:IsReady() and (Player:BuffRemains(S.CoagulopathyBuff) <= Player:GCD() or Player:BuffRemains(S.IcyTalonsBuff) <= Player:GCD() or Player:RunicPower() >= VarDeathStrikeDumpAmt or Player:RunicPowerDeficit() <= VarHeartStrikeRP or Target:TimeToDie() < 10) then
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike main 10"; end
    end
    -- blooddrinker,if=!buff.dancing_rune_weapon.up
    if S.Blooddrinker:IsReady() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
      if Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker main 12"; end
    end
    -- call_action_list,name=racials
    if (CDsON()) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- sacrificial_pact,if=!buff.dancing_rune_weapon.up&(pet.ghoul.remains<2|target.time_to_die<gcd)
    if CDsON() and S.SacrificialPact:IsReady() and Ghoul.GhoulActive() and (Player:BuffDown(S.DancingRuneWeaponBuff) and (Ghoul.GhoulRemains() < 2 or Target:TimeToDie() < Player:GCD())) then
      if Cast(S.SacrificialPact, Settings.CommonsOGCD.GCDasOffGCD.SacrificialPact) then return "sacrificial_pact main 14"; end
    end
    -- blood_tap,if=(rune<=2&rune.time_to_4>gcd&charges_fractional>=1.8)|rune.time_to_3>gcd
    if CDsON() and S.BloodTap:IsCastable() and ((Player:Rune() <= 2 and Player:RuneTimeToX(4) > Player:GCD() and S.BloodTap:ChargesFractional() >= 1.8) or Player:RuneTimeToX(3) > Player:GCD()) then
      if Cast(S.BloodTap, Settings.Blood.OffGCDasOffGCD.BloodTap) then return "blood_tap main 16"; end
    end
    -- gorefiends_grasp,if=talent.tightening_grasp.enabled
    if CDsON() and S.GorefiendsGrasp:IsCastable() and (S.TighteningGrasp:IsAvailable()) then
      if Cast(S.GorefiendsGrasp, Settings.Blood.GCDasOffGCD.GorefiendsGrasp, nil, not Target:IsSpellInRange(S.GorefiendsGrasp)) then return "gorefiends_grasp main 18"; end
    end
    -- empower_rune_weapon,if=rune<6&runic_power.deficit>5
    if CDsON() and S.EmpowerRuneWeapon:IsCastable() and (Player:Rune() < 6 and Player:RunicPowerDeficit() > 5) then
      if Cast(S.EmpowerRuneWeapon, Settings.CommonsOGCD.GCDasOffGCD.EmpowerRuneWeapon) then return "empower_rune_weapon main 20"; end
    end
    -- abomination_limb
    if CDsON() and S.AbominationLimb:IsCastable() then
      if Cast(S.AbominationLimb, nil, Settings.CommonsDS.DisplayStyle.AbominationLimb, not Target:IsInRange(20)) then return "abomination_limb main 22"; end
    end
    -- dancing_rune_weapon,if=!buff.dancing_rune_weapon.up
    if CDsON() and S.DancingRuneWeapon:IsCastable() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
      if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon main 24"; end
    end
    -- run_action_list,name=drw_up,if=buff.dancing_rune_weapon.up
    if (Player:BuffUp(S.DancingRuneWeaponBuff)) then
      local ShouldReturn = DRWUp(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool for DRWUp"; end
    end
    -- call_action_list,name=standard
    local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    -- Pool if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.MarkofFyralathDebuff:RegisterAuraTracking()

  HR.Print("Blood Death Knight rotation has been updated for patch 10.2.7.")
end

HR.SetAPL(250, APL, Init)
