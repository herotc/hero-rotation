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
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DeathKnight.Blood
local I = Item.DeathKnight.Blood

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Rotation Var
local ShouldReturn
local IsTanking
local EnemiesMelee
local EnemiesMeleeCount
local UnitsWithoutBloodPlague

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Blood = HR.GUISettings.APL.DeathKnight.Blood
}

--Functions
local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function UnitsWithoutBP(enemies)
  local WithoutBPCount = 0
  for _, CycleUnit in pairs(enemies) do
    if not CycleUnit:DebuffUp(S.BloodPlagueDebuff) then
      WithoutBPCount = WithoutBPCount + 1
    end
  end
  return WithoutBPCount
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion"; end
    end
    -- use_item,name=azsharas_font_of_power
    -- use_item,effect_name=cyclotronic_blast
    -- Manually added: Openers
    if S.DeathsCaress:IsReady() and not Target:IsInMeleeRange(5) then
      if HR.Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress"; end
    end
    if S.Marrowrend:IsReady() and Target:IsInMeleeRange(5) then
      if HR.Cast(S.Marrowrend) then return "marrowrend"; end
    end
    if S.BloodBoil:IsCastable() and Target:IsInMeleeRange(10) then
      if HR.Cast(S.BloodBoil) then return "blood_boil"; end
    end
  end
end

local function Defensives()
  -- Rune Tap Emergency
  if S.RuneTap:IsReady() and IsTanking and Player:HealthPercentage() <= 40 and Player:Rune() >= 3 and S.RuneTap:Charges() >= 1 and Player:BuffDown(S.RuneTapBuff) then
    if HR.Cast(S.RuneTap, Settings.Blood.OffGCDasOffGCD.RuneTap) then return "rune_tap"; end
  end
  -- Active Mitigation
  if Player:ActiveMitigationNeeded() and S.Marrowrend:TimeSinceLastCast() > 2.5 and S.DeathStrike:TimeSinceLastCast() > 2.5 then
    if S.DeathStrike:IsReady() and Player:BuffStack(S.BoneShieldBuff) > 7 then
      if HR.Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike"; end
    end
    if S.Marrowrend:IsReady() then
      if HR.Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend"; end
    end
    if S.Tombstone:IsReady() and Player:BuffStack(S.BoneShieldBuff) >= 7 then
      if HR.Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone"; end
    end
    if S.DeathStrike:IsReady() then
      if HR.Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike"; end
    end
  end
  -- Bone Shield
  if S.Marrowrend:IsReady() and (Player:BuffRemains(S.BoneShieldBuff) <= 6 or (Target:TimeToDie() < 5 and Player:BuffRemains(S.BoneShieldBuff) < 10 and EnemiesMeleeCount == 1)) then
    if HR.Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend"; end
  end
  -- Vampiric Blood
  if S.VampiricBlood:IsCastable() and IsTanking and Player:HealthPercentage() <= 65 and Player:BuffDown(S.IceboundFortitudeBuff) then
    if HR.Cast(S.VampiricBlood, Settings.Blood.GCDasOffGCD.VampiricBlood) then return "vampiric_blood"; end
  end
  -- Icebound Fortitude
  if S.IceboundFortitude:IsCastable() and IsTanking and Player:HealthPercentage() <= 50 and Player:BuffDown(S.VampiricBloodBuff) then
    if HR.Cast(S.IceboundFortitude, Settings.Blood.GCDasOffGCD.IceboundFortitude) then return "icebound_fortitude"; end
  end
  -- Healing
  if S.DeathStrike:IsReady() and Player:HealthPercentage() <= 50 + (Player:RunicPower() > 90 and 20 or 0) and not Player:HealingAbsorbed() then
    if HR.Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike"; end
  end
end

local function Standard()
  -- death_strike,if=runic_power.deficit<=10
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= 10) then
    if HR.Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike"; end
  end
  -- blooddrinker,if=!buff.dancing_rune_weapon.up
  if S.Blooddrinker:IsReady() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if HR.Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker"; end
  end
  -- marrowrend,if=(buff.bone_shield.remains<=rune.time_to_3|buff.bone_shield.remains<=(gcd+cooldown.blooddrinker.ready*talent.blooddrinker.enabled*2)|buff.bone_shield.stack<3)&runic_power.deficit>=20
  if S.Marrowrend:IsReady() and ((Player:BuffRemains(S.BoneShieldBuff) <= Player:RuneTimeToX(3) or Player:BuffRemains(S.BoneShieldBuff) <= (Player:GCD() + num(S.Blooddrinker:IsAvailable() and S.Blooddrinker:CooldownUp()) * 2) or Player:BuffStack(S.BoneShieldBuff) < 3) and Player:RunicPowerDeficit() >= 20) then
    if HR.Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend"; end
  end
  -- blood_boil,if=charges_fractional>=1.8&(buff.hemostasis.stack<=(5-spell_targets.blood_boil)|spell_targets.blood_boil>2)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.8 and (Player:BuffStack(S.HemostasisBuff) <= (5 - EnemiesCount10y) or EnemiesCount10y > 2)) then
    if HR.Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil"; end
  end
  -- marrowrend,if=buff.bone_shield.stack<5&runic_power.deficit>=15
  if S.Marrowrend:IsReady() and (Player:BuffStack(S.BoneShieldBuff) < 5 and Player:RunicPowerDeficit() >= 15) then
    if HR.Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend"; end
  end
  -- bonestorm,if=runic_power>=100&!buff.dancing_rune_weapon.up
  if S.Bonestorm:IsReady() and (Player:RunicPower() >= 100 and Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if HR.Cast(S.Bonestorm, nil, nil, not Target:IsInRange(8)) then return "bonestorm"; end
  end
  -- death_strike,if=runic_power.deficit<=(15+buff.dancing_rune_weapon.up*5+spell_targets.heart_strike*talent.heartbreaker.enabled*2)|target.1.time_to_die<10
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= (15 + num(Player:BuffUp(S.DancingRuneWeaponBuff)) * 5 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2) or Target:TimeToDie() < 10) then
    if HR.Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike"; end
  end
  -- death_and_decay,if=spell_targets.death_and_decay>=3
  if (EnemiesMeleeCount >= 3) then
    if S.DeathandDecay:IsReady() then
      if HR.Cast(S.DeathandDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay"; end
    end
    if S.DeathsDue:IsReady() then
      if HR.Cast(S.DeathsDue, nil, nil, not Target:IsInRange(30)) then return "deaths_due"; end
    end
  end
  -- heart_strike,if=buff.dancing_rune_weapon.up|rune.time_to_4<gcd
  if S.HeartStrike:IsReady() and (Player:BuffUp(S.DancingRuneWeaponBuff) or Player:RuneTimeToX(4) < Player:GCD()) then
    if HR.Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike"; end
  end
  -- blood_boil,if=buff.dancing_rune_weapon.up
  if S.BloodBoil:IsCastable() and (Player:BuffUp(S.DancingRuneWeaponBuff)) then
    if HR.Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil"; end
  end
  -- death_and_decay,if=buff.crimson_scourge.up|talent.rapid_decomposition.enabled|spell_targets.death_and_decay>=2
  if (Player:BuffUp(S.CrimsonScourgeBuff) or S.RapidDecomposition:IsAvailable() or EnemiesMeleeCount >= 2) then
    if S.DeathandDecay:IsReady() then
      if HR.Cast(S.DeathandDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay"; end
    end
    if S.DeathsDue:IsReady() then
      if HR.Cast(S.DeathsDue, nil, nil, not Target:IsInRange(30)) then return "deaths_due"; end
    end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if HR.Cast(S.Consumption, nil, nil, not Target:IsSpellInRange(S.Consumption)) then return "consumption"; end
  end
  -- blood_boil
  if S.BloodBoil:IsCastable() then
    if HR.Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil"; end
  end
  -- heart_strike,if=rune.time_to_3<gcd|buff.bone_shield.stack>6
  if S.HeartStrike:IsReady() and (Player:RuneTimeToX(3) < Player:GCD() or Player:BuffStack(S.BoneShieldBuff) > 6) then
    if HR.Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike"; end
  end
  -- use_item,name=grongs_primal_rage
  -- arcane_torrent,if=runic_power.deficit>20
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 20) then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInMeleeRange(8)) then return "arcane_torrent"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Get Enemies Count
  Enemies10y          = Player:GetEnemiesInRange(10)
  if AoEON() then
    EnemiesMelee      = Player:GetEnemiesInMeleeRange(8)
    EnemiesMeleeCount = #EnemiesMelee
    EnemiesCount10y   = #Enemies10y
  else
    EnemiesMeleeCount = 1
    EnemiesCount10y   = 1
  end
  
  -- Check Units without Blood Plague
  UnitsWithoutBloodPlague = UnitsWithoutBP(Enemies10y)
  
  -- Are we actively tanking?
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)
  
  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Defensives
    local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, false); if ShouldReturn then return ShouldReturn; end
    if Settings.Blood.PoolDuringBlooddrinker and Player:IsChanneling(S.Blooddrinker) and Player:BuffUp(S.BoneShieldBuff) and UnitsWithoutBloodPlague == 0 and not Player:ShouldStopCasting() and Player:CastRemains() > 0.2 then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool During Blooddrinker"; end
    end
    -- auto_attack
    -- blood_fury,if=cooldown.dancing_rune_weapon.ready&(!cooldown.blooddrinker.ready|!talent.blooddrinker.enabled)
    if S.BloodFury:IsCastable() and (S.DancingRuneWeapon:CooldownUp() and (not S.Blooddrinker:IsReady() or not S.Blooddrinker:IsAvailable())) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury"; end
    end
    -- berserking
    if S.Berserking:IsCastable() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking"; end
    end
    -- arcane_pulse,if=active_enemies>=2|rune<1&runic_power.deficit>60
    if S.ArcanePulse:IsCastable() then
      if HR.Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse"; end
    end
    -- lights_judgment,if=buff.unholy_strength.up
    if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff)) then
      if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment"; end
    end
    -- ancestral_call
    if S.AncestralCall:IsCastable() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
    end
    -- fireblood
    if S.Fireblood:IsCastable() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood"; end
    end
    -- bag_of_tricks
    if S.BagofTricks:IsCastable() then
      if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks"; end
    end
    -- use_items,if=cooldown.dancing_rune_weapon.remains>90
    if (S.DancingRuneWeapon:CooldownRemains() > 90) then
      local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- use_item,name=razdunks_big_red_button
    -- use_item,effect_name=cyclotronic_blast,if=cooldown.dancing_rune_weapon.remains&!buff.dancing_rune_weapon.up&rune.time_to_4>cast_time
    -- use_item,name=azsharas_font_of_power,if=(cooldown.dancing_rune_weapon.remains<5&target.time_to_die>15)|(target.time_to_die<34)
    -- use_item,name=merekthas_fang,if=(cooldown.dancing_rune_weapon.remains&!buff.dancing_rune_weapon.up&rune.time_to_4>3)&!raid_event.adds.exists|raid_event.adds.in>15
    -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down
    -- use_item,name=ashvanes_razor_coral,if=target.health.pct<31&equipped.dribbling_inkpod
    -- use_item,name=ashvanes_razor_coral,if=buff.dancing_rune_weapon.up&debuff.razor_coral_debuff.up&!equipped.dribbling_inkpod
    -- vampiric_blood (Moved to Defensives)
    -- potion,if=buff.dancing_rune_weapon.up
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.DancingRuneWeaponBuff)) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion"; end
    end
    -- dancing_rune_weapon,if=!talent.blooddrinker.enabled|!cooldown.blooddrinker.ready
    if S.DancingRuneWeapon:IsCastable() and (not S.Blooddrinker:IsAvailable() or not S.Blooddrinker:CooldownUp()) then
      if HR.Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon"; end
    end
    -- tombstone,if=buff.bone_shield.stack>=7 (Moved to Defensives)
    -- call_action_list,name=essences (Removed for Shadowlands)
    -- call_action_list,name=standard
    local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    -- Pool if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()

end

HR.SetAPL(250, APL, Init)
