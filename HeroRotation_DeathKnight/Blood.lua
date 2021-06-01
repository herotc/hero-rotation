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
local ghoul = HL.GhoulTable


-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DeathKnight.Commons,
  Blood = HR.GUISettings.APL.DeathKnight.Blood
}

-- Stun Interrupts List
local StunInterrupts = {
  {S.Asphyxiate, "Cast Asphyxiate (Interrupt)", function () return true; end},
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
    -- Manually added: Openers
    if S.DeathsCaress:IsReady() and not Target:IsInMeleeRange(5) then
      if Cast(S.DeathsCaress, nil, nil, not Target:IsSpellInRange(S.DeathsCaress)) then return "deaths_caress precombat 2"; end
    end
    if S.Marrowrend:IsReady() and Target:IsInMeleeRange(5) then
      if Cast(S.Marrowrend) then return "marrowrend precombat 4"; end
    end
    if S.BloodBoil:IsCastable() and Target:IsInMeleeRange(10) then
      if Cast(S.BloodBoil) then return "blood_boil precombat 6"; end
    end
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
      if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend defensives 6"; end
    end
    if S.Tombstone:IsReady() and Player:BuffStack(S.BoneShieldBuff) >= 7 then
      if Cast(S.Tombstone, Settings.Blood.GCDasOffGCD.Tombstone) then return "tombstone defensives 8"; end
    end
    if S.DeathStrike:IsReady() then
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 10"; end
    end
  end
  -- Bone Shield
  if S.Marrowrend:IsReady() and (Player:BuffRemains(S.BoneShieldBuff) <= 6 or (Target:TimeToDie() < 5 and Player:BuffRemains(S.BoneShieldBuff) < 10 and EnemiesMeleeCount == 1)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend defensives 12"; end
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
  if S.DeathStrike:IsReady() and Player:HealthPercentage() <= 50 + (Player:RunicPower() > 90 and 20 or 0) and not Player:HealingAbsorbed() then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike defensives 18"; end
  end
end

local function Standard()
  -- blood_tap,if=rune<=2&rune.time_to_4>gcd&charges_fractional>=1.8
  if S.BloodTap:IsCastable() and (Player:Rune() <= 2 and Player:RuneTimeToX(4) > Player:GCD() and S.BloodTap:ChargesFractional() >= 1.8) then
    if Cast(S.BloodTap) then return "blood_tap standard 2"; end
  end
  -- dancing_rune_weapon,if=!talent.blooddrinker.enabled|!cooldown.blooddrinker.ready
  if S.DancingRuneWeapon:IsCastable() and (not S.Blooddrinker:IsAvailable() or not S.Blooddrinker:CooldownUp()) then
    if Cast(S.DancingRuneWeapon, Settings.Blood.GCDasOffGCD.DancingRuneWeapon) then return "dancing_rune_weapon standard 4"; end
  end
  -- tombstone,if=buff.bone_shield.stack>=7&rune>=2
  -- Moved to Defensives
  -- marrowrend,if=(!covenant.necrolord|buff.abomination_limb.up)&(buff.bone_shield.remains<=rune.time_to_3|buff.bone_shield.remains<=(gcd+cooldown.blooddrinker.ready*talent.blooddrinker.enabled*2)|buff.bone_shield.stack<3)&runic_power.deficit>=20
  if S.Marrowrend:IsReady() and ((Player:Covenant() ~= "Necrolord" or Player:BuffUp(S.AbominationLimbBuff)) and (Player:BuffRemains(S.BoneShieldBuff) <= Player:RuneTimeToX(3) or Player:BuffRemains(S.BoneShieldBuff) <= (Player:GCD() + num(S.Blooddrinker:CooldownUp()) * num(S.Blooddrinker:IsAvailable()) * 2) or Player:BuffStack(S.BoneShieldBuff) < 3) and Player:RunicPowerDeficit() >= 20) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend standard 8"; end
  end
  -- death_strike,if=runic_power.deficit<=70
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= 70) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike standard 10"; end
  end
  -- marrowrend,if=buff.bone_shield.stack<6&runic_power.deficit>=15&(!covenant.night_fae|buff.deaths_due.remains>5)
  if S.Marrowrend:IsReady() and (Player:BuffStack(S.BoneShieldBuff) < 6 and Player:RunicPowerDeficit() >= 15 and (Player:Covenant() ~= "Night Fae" or Player:BuffRemains(S.DeathsDueBuff) > 5)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend standard 12"; end
  end
  -- heart_strike,if=!talent.blooddrinker.enabled&death_and_decay.remains<5&runic_power.deficit<=(15+buff.dancing_rune_weapon.up*5+spell_targets.heart_strike*talent.heartbreaker.enabled*2)
  if S.HeartStrike:IsReady() and (not S.Blooddrinker:IsAvailable() and Player:BuffRemains(S.DeathAndDecayBuff) < 5 and Player:RunicPowerDeficit() <= (15 + num(Player:BuffUp(S.DancingRuneWeaponBuff)) * 5 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2)) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike standard 14"; end
  end
  -- blood_boil,if=charges_fractional>=1.8&(buff.hemostasis.stack<=(5-spell_targets.blood_boil)|spell_targets.blood_boil>2)
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.8 and (Player:BuffStack(S.HemostasisBuff) <= (5 - EnemiesCount10y) or EnemiesCount10y > 2)) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil standard 16"; end
  end
  -- death_and_decay,if=(buff.crimson_scourge.up&talent.relish_in_blood.enabled)&runic_power.deficit>10
  if S.DeathAndDecay:IsReady() and ((Player:BuffUp(S.CrimsonScourgeBuff) and S.RelishinBlood:IsAvailable()) and Player:RunicPowerDeficit() > 10) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay standard 18"; end
  end
  -- bonestorm,if=runic_power>=100&!buff.dancing_rune_weapon.up
  if S.Bonestorm:IsReady() and (Player:RunicPower() >= 100 and Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.Bonestorm, nil, nil, not Target:IsInRange(8)) then return "bonestorm standard 20"; end
  end
  -- death_strike,if=runic_power.deficit<=(15+buff.dancing_rune_weapon.up*5+spell_targets.heart_strike*talent.heartbreaker.enabled*2)|target.1.time_to_die<10
  if S.DeathStrike:IsReady() and (Player:RunicPowerDeficit() <= (15 + num(Player:BuffUp(S.DancingRuneWeaponBuff)) * 5 + EnemiesMeleeCount * num(S.Heartbreaker:IsAvailable()) * 2) or Target:TimeToDie() < 10) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike standard 22"; end
  end
  -- death_and_decay,if=spell_targets.death_and_decay>=3
  if S.DeathAndDecay:IsReady() and (EnemiesMeleeCount >= 3) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay standard 24"; end
  end
  -- heart_strike,if=buff.dancing_rune_weapon.up|rune.time_to_4<gcd
  if S.HeartStrike:IsReady() and (Player:BuffUp(S.DancingRuneWeaponBuff) or Player:RuneTimeToX(4) < Player:GCD()) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike standard 26"; end
  end
  -- blood_boil,if=buff.dancing_rune_weapon.up
  if S.BloodBoil:IsCastable() and (Player:BuffUp(S.DancingRuneWeaponBuff)) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil standard 28"; end
  end
  -- blood_tap,if=rune.time_to_3>gcd
  if S.BloodTap:IsCastable() and (Player:RuneTimeToX(3) > Player:GCD()) then
    if Cast(S.BloodTap) then return "blood_tap standard 30"; end
  end
  -- death_and_decay,if=buff.crimson_scourge.up|talent.rapid_decomposition.enabled|spell_targets.death_and_decay>=2
  if S.DeathAndDecay:IsReady() and (Player:BuffUp(S.CrimsonScourgeBuff) or S.RapidDecomposition:IsAvailable() or EnemiesMeleeCount >= 2) then
    if Cast(S.DeathAndDecay, nil, nil, not Target:IsInRange(30)) then return "death_and_decay standard 32"; end
  end
  -- consumption
  if S.Consumption:IsCastable() then
    if Cast(S.Consumption, nil, Settings.Blood.DisplayStyle.Consumption, not Target:IsSpellInRange(S.Consumption)) then return "consumption standard 34"; end
  end
  -- blood_boil,if=charges_fractional>=1.1
  if S.BloodBoil:IsCastable() and (S.BloodBoil:ChargesFractional() >= 1.1) then
    if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil standard 36"; end
  end
  -- heart_strike,if=(rune>1&(rune.time_to_3<gcd|buff.bone_shield.stack>7))
  if S.HeartStrike:IsReady() and (Player:Rune() > 1 and (Player:RuneTimeToX(3) < Player:GCD() or Player:BuffStack(S.BoneShieldBuff) > 7)) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike standard 38"; end
  end
  -- arcane_torrent,if=runic_power.deficit>20
  if S.ArcaneTorrent:IsCastable() and (Player:RunicPowerDeficit() > 20) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInMeleeRange(8)) then return "arcane_torrent standard 40"; end
  end
end

local function Covenants()
  -- death_strike,if=covenant.night_fae&buff.deaths_due.remains>6&runic_power>70
  if S.DeathStrike:IsReady() and (Player:Covenant() == "Night Fae" and Player:BuffRemains(S.DeathsDueBuff) > 6 and Player:RunicPower() > 70) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike covenants 2"; end
  end
  -- heart_strike,if=covenant.night_fae&death_and_decay.ticking&((buff.deaths_due.up|buff.dancing_rune_weapon.up)&buff.deaths_due.remains<6)
  if S.HeartStrike:IsReady() and (Player:Covenant() == "Night Fae" and Player:BuffUp(S.DeathAndDecayBuff) and ((Player:BuffUp(S.DeathsDueBuff) or Player:BuffUp(S.DancingRuneWeaponBuff)) and Player:BuffRemains(S.DeathsDueBuff))) then
    if Cast(S.HeartStrike, nil, nil, not Target:IsSpellInRange(S.HeartStrike)) then return "heart_strike covenants 4"; end
  end
  -- deaths_due,if=!buff.deaths_due.up|buff.deaths_due.remains<4|buff.crimson_scourge.up
  if S.DeathsDue:IsReady() and (Player:BuffDown(S.DeathsDueBuff) or Player:BuffRemains(S.DeathsDueBuff) < 4 or Player:BuffUp(S.CrimsonScourgeBuff)) then
    if Cast(S.DeathsDue, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DeathsDue)) then return "deaths_due covenants 6"; end
  end
  -- sacrificial_pact,if=(!covenant.night_fae|buff.deaths_due.remains>6)&!buff.dancing_rune_weapon.up&(pet.ghoul.remains<10|target.time_to_die<gcd)
  -- Note: Manually changed target.time_to_die to fight_remains to stop suggesting when one mob in a pack is about to die.
  if ghoul.active() and S.SacrificialPact:IsReady() and ((Player:Covenant() ~= "Night Fae" or Player:BuffRemains(S.DeathsDueBuff) > 6) and Player:BuffDown(S.DancingRuneWeaponBuff) and (ghoul.remains() < 10 or HL.FilteredFightRemains(Enemies10y, "<", Player:GCD()))) then
    if Cast(S.SacrificialPact, Settings.Commons.OffGCDasOffGCD.SacrificialPact) then return "sacrificial_pact covenants 8"; end
  end
  -- death_strike,if=covenant.venthyr&runic_power>70&cooldown.swarming_mist.remains<3
  if S.DeathStrike:IsReady() and (Player:Covenant() == "Venthyr" and Player:RunicPower() > 70 and S.SwarmingMist:CooldownRemains() < 3) then
    if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike covenants 10"; end
  end
  -- swarming_mist,if=!buff.dancing_rune_weapon.up
  if S.SwarmingMist:IsReady() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.SwarmingMist, nil, Settings.Commons.DisplayStyle.Covenant) then return "swarming_mist covenants 12"; end
  end
  -- marrowrend,if=covenant.necrolord&buff.bone_shield.stack<=0
  if S.Marrowrend:IsReady() and (Player:Covenant() == "Necrolord" and Player:BuffDown(S.BoneShieldBuff)) then
    if Cast(S.Marrowrend, nil, nil, not Target:IsSpellInRange(S.Marrowrend)) then return "marrowrend covenants 14"; end
  end
  -- abomination_limb,if=!buff.dancing_rune_weapon.up
  if S.AbominationLimb:IsCastable() and (Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.AbominationLimb, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(8)) then return "abomination_limb covenants 16"; end
  end
  -- shackle_the_unworthy,if=cooldown.dancing_rune_weapon.remains<3|!buff.dancing_rune_weapon.up
  if S.ShackleTheUnworthy:IsCastable() and (S.DancingRuneWeapon:CooldownRemains() < 3 or Player:BuffDown(S.DancingRuneWeaponBuff)) then
    if Cast(S.ShackleTheUnworthy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ShackleTheUnworthy)) then return "shackle_the_unworthy covenants 18"; end
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
    local ShouldReturn = Everyone.Interrupt(15, S.MindFreeze, Settings.Commons.OffGCDasOffGCD.MindFreeze, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Display Pool icon if PoolDuringBlooddrinker is true
    if Settings.Blood.PoolDuringBlooddrinker and Player:IsChanneling(S.Blooddrinker) and Player:BuffUp(S.BoneShieldBuff) and UnitsWithoutBloodPlague == 0 and not Player:ShouldStopCasting() and Player:CastRemains() > 0.2 then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool During Blooddrinker"; end
    end
    -- auto_attack
    if CDsON() then
      -- blood_fury,if=cooldown.dancing_rune_weapon.ready&(!cooldown.blooddrinker.ready|!talent.blooddrinker.enabled)
      if S.BloodFury:IsCastable() and (S.DancingRuneWeapon:CooldownUp() and (not S.Blooddrinker:IsReady() or not S.Blooddrinker:IsAvailable()))  then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 2"; end
      end
      -- berserking
      if S.Berserking:IsCastable() then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 4"; end
      end
      -- arcane_pulse,if=active_enemies>=2|rune<1&runic_power.deficit>60
      if S.ArcanePulse:IsCastable() and (EnemiesMeleeCount >= 2 or Player:Rune() < 1 and Player:RunicPowerDeficit() > 60) then
        if Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_pulse main 6"; end
      end
      -- lights_judgment,if=buff.unholy_strength.up
      if S.LightsJudgment:IsCastable() and (Player:BuffUp(S.UnholyStrengthBuff)) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 8"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 10"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 12"; end
      end
      -- bag_of_tricks
      if S.BagofTricks:IsCastable() then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 14"; end
      end
    end
    -- potion,if=buff.dancing_rune_weapon.up
    if I.PotionofPhantomFire:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.DancingRuneWeaponBuff)) then
      if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 16"; end
    end
    -- use_items
    if (Settings.Commons.Enabled.Trinkets) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- raise_dead
    if S.RaiseDead:IsCastable() then
      if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead main 18"; end
    end
    -- blooddrinker,if=!buff.dancing_rune_weapon.up&(!covenant.night_fae|buff.deaths_due.remains>7)
    if S.Blooddrinker:IsReady() and (Player:BuffDown(S.DancingRuneWeaponBuff) and (Player:Covenant() ~= "Night Fae" or Player:BuffRemains(S.DeathsDueBuff) > 7)) then
      if Cast(S.Blooddrinker, nil, nil, not Target:IsSpellInRange(S.Blooddrinker)) then return "blooddrinker main 20"; end
    end
    -- blood_boil,if=charges>=2&(covenant.kyrian|buff.dancing_rune_weapon.up)
    if S.BloodBoil:IsCastable() and (S.BloodBoil:Charges() >= 2 and (Player:Covenant() == "Kyrian" or Player:BuffUp(S.DancingRuneWeaponBuff))) then
      if Cast(S.BloodBoil, Settings.Blood.GCDasOffGCD.BloodBoil, nil, not Target:IsInMeleeRange(10)) then return "blood_boil main 22"; end
    end
    -- raise_dead
    if CDsON() and S.RaiseDead:IsCastable() then
      if Cast(S.RaiseDead, nil, Settings.Commons.DisplayStyle.RaiseDead) then return "raise_dead main 24"; end
    end
    -- death_strike,if=fight_remains<3
    if S.DeathStrike:IsReady() and (HL.FilteredFightRemains(Enemies10y, "<", 3)) then
      if Cast(S.DeathStrike, Settings.Blood.GCDasOffGCD.DeathStrike, nil, not Target:IsSpellInRange(S.DeathStrike)) then return "death_strike main 26"; end
    end
    -- call_action_list,name=covenants
    if (true) then
      local ShouldReturn = Covenants(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=standard
    if (true) then
      local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Blood DK rotation is currently a work in progress.")
end

HR.SetAPL(250, APL, Init)
